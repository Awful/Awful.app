//  RenderView.js
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// This file is loaded as a user script "at document end" into the `WKWebView` that renders announcements, posts, profiles, and private messages.

"use strict";

if (!window.Awful) {
    window.Awful = {};
}

// MARK: - Configuration Constants

/// Number of post images to load immediately before lazy loading kicks in
/// IMPORTANT: This value must match immediatelyLoadedImageCount constant in HTMLRenderingHelpers.swift
const IMMEDIATELY_LOADED_IMAGE_COUNT = 10;

/// How far ahead (in pixels) to start loading lazy content before it enters viewport
const LAZY_LOAD_LOOKAHEAD_DISTANCE = '600px';

/// CSS selectors used throughout the code
const SELECTORS = {
    LOADING_IMAGES: 'section.postbody img[src]:not(.awful-smile):not(.awful-avatar):not([loading="lazy"])',
    POST_ELEMENTS: 'post',
    LOTTIE_PLAYERS: 'lottie-player'
};

/// Timeout configuration for image loading
const IMAGE_LOAD_TIMEOUT_CONFIG = {
    /// Maximum number of checks for initial image loading timeout detection
    /// 3 checks × 1000ms = 3 seconds max wait for images to start loading
    maxImageChecks: 3,

    /// Milliseconds to wait before resetting retry button text after failed retry
    /// 3000ms gives user time to read the error message before it resets
    retryResetDelay: 3000
};

/// Timeout for tweet embedding via Twitter API
/// 5 seconds gives enough time for API response while preventing indefinite waiting
const TWEET_EMBED_TIMEOUT = 5000;

// MARK: - Utility Functions

/**
 * Sets up a Lottie player to load ghost animation data.
 * Helper to avoid code duplication for dead tweet/image badge initialization.
 * Properly removes existing listeners before adding new ones to prevent accumulation.
 *
 * @param {HTMLElement} container - The container element containing lottie-player elements
 */
Awful.setupGhostLottiePlayer = function(container) {
    const players = container.querySelectorAll(SELECTORS.LOTTIE_PLAYERS);
    players.forEach((lottiePlayer) => {
        if (lottiePlayer._ghostLoadHandler) {
            lottiePlayer.removeEventListener("rendered", lottiePlayer._ghostLoadHandler);
        }

        lottiePlayer._ghostLoadHandler = () => {
            const ghostData = document.getElementById("ghost-json-data");
            if (ghostData) {
                lottiePlayer.load(ghostData.innerText);
            }
        };

        lottiePlayer.addEventListener("rendered", lottiePlayer._ghostLoadHandler);
    });
};

/**
 * Sanitizes a URL to prevent XSS attacks.
 * Ensures URLs don't contain dangerous protocols like javascript: or data:text/html
 *
 * @param {string} url - The URL to sanitize
 * @returns {string} The sanitized URL or '#' if dangerous
 */
Awful.sanitizeURL = function(url) {
    if (!url) return '#';

    const urlLower = url.trim().toLowerCase();

    // Block dangerous protocols
    if (urlLower.startsWith('javascript:') ||
        urlLower.startsWith('vbscript:')) {
        return '#';
    }

    // Block all data: URLs except safe image formats
    if (urlLower.startsWith('data:') &&
        !urlLower.startsWith('data:image/')) {
        return '#';
    }

    return url;
};

/**
 * HTML-escapes a string to prevent XSS when used in HTML context.
 *
 * @param {string} str - The string to escape
 * @returns {string} The escaped string
 */
Awful.escapeHTML = function(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
};

/**
 * Helper for consistent error handling when images fail to load.
 * Replaces failed images with dead image badges and optionally updates progress tracker.
 *
 * @param {Error} error - The error that occurred
 * @param {string} url - The URL that failed to load
 * @param {HTMLImageElement} img - The image element that failed
 * @param {string} imageID - Unique ID for this image
 * @param {boolean} enableGhost - Whether to show dead image badge
 * @param {boolean} trackProgress - Whether to increment the progress tracker (default: true)
 */
Awful.handleImageLoadError = function(error, url, img, imageID, enableGhost, trackProgress = true) {
    console.error(`Image load failed: ${error.message} - ${url}`);

    if (enableGhost && img.parentNode) {
        const div = document.createElement('div');
        div.classList.add('dead-embed-container');
        div.innerHTML = Awful.deadImageBadgeHTML(url, imageID);
        img.parentNode.replaceChild(div, img);

        // Use helper function to set up Lottie player (fixes code duplication)
        Awful.setupGhostLottiePlayer(div);
    }

    // Only increment progress for initially loaded images, not lazy-loaded ones
    if (trackProgress) {
        Awful.imageLoadTracker.incrementLoaded();
    }
};

/**
 Retrieves an OEmbed HTML fragment.
 
 @param url The OEmbed URL.
 @returns The OEmbed response, probably JSON of some kind.
 @throws When the OEmbed response is unavailable.
 */
Awful.fetchOEmbed = async function(url) {
  return new Promise((resolve, reject) => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    const id = [...new Array(8)].map(_ => chars.charAt(Math.floor(Math.random() * chars.length))).join('');
    waitingOEmbedResponses[id] = function(response) {
      delete waitingOEmbedResponses[id];
      if (response.error) {
        reject(response.error);
      } else {
        resolve(response.body);
      }
    };
    window.webkit.messageHandlers.fetchOEmbedFragment.postMessage({ id, url });
  });
};

// MARK: - Tweet Embedding Helper Functions

/**
 * Shows a dead tweet badge for a failed tweet.
 * Centralizes the logic for displaying dead tweet badges to avoid code duplication
 * between main embedding and retry functionality.
 *
 * @param {string} tweetID - The tweet ID
 * @param {string} tweetURL - The original tweet URL
 * @param {Element} containerToReplace - The element to replace with dead badge
 */
Awful.showDeadTweetBadge = function(tweetID, tweetURL, containerToReplace) {
    if (!window.Awful.renderGhostTweets || !containerToReplace || !containerToReplace.parentNode) {
        return;
    }

    const div = document.createElement('div');
    div.classList.add('dead-tweet-container');
    div.innerHTML = Awful.deadTweetBadgeHTML(tweetURL, tweetID);
    containerToReplace.parentNode.replaceChild(div, containerToReplace);
    Awful.setupGhostLottiePlayer(div);
};

/**
 * Calls Twitter widgets.load() with proper race condition handling.
 * Checks if widgets.js is fully loaded (has widgets property), otherwise queues the call
 * via twttr.ready() to ensure it executes after widgets.js finishes loading.
 */
Awful.loadTwitterWidgetsForEmbeds = function() {
    if (!window.twttr) {
        return;
    }

    if (window.twttr.widgets) {
        // Real widgets.js is loaded (has widgets property), call immediately
        twttr.widgets.load();
    } else {
        // widgets.js still loading (only has stub), queue the call
        twttr.ready(function() {
            twttr.widgets.load();
        });
    }
};

/**
 * Fetches a single tweet via JSONP with timeout protection and comprehensive error handling.
 * Centralizes all tweet fetching logic to ensure consistent behavior between main embedding
 * and retry functionality.
 *
 * @param {string} tweetID - The tweet ID to fetch
 * @param {Function} onSuccess - Called with (data, tweetID) on successful fetch
 * @param {Function} onFailure - Called with (reason, tweetID, data) on failure
 *                                 reason can be: 'timeout', 'api_error', 'network'
 * @returns {object} - Object with cleanup() function to manually abort the request
 */
Awful.fetchTweetOEmbed = function(tweetID, onSuccess, onFailure) {
    // Create unique callback name to prevent collisions when same tweet appears in multiple posts
    let callback = `jsonp_callback_${tweetID}`;
    let counter = 0;
    while (window[callback]) {
        callback = `jsonp_callback_${tweetID}_${++counter}`;
    }

    const script = document.createElement('script');
    const tweetTheme = Awful.tweetTheme();
    const validThemes = ['light', 'dark'];
    const safeTheme = validThemes.includes(tweetTheme) ? tweetTheme : 'light';
    script.src = `https://api.twitter.com/1/statuses/oembed.json?id=${tweetID}&omit_script=true&dnt=true&theme=${safeTheme}&callback=${callback}`;

    let timedOut = false;

    let timeoutId = setTimeout(function() {
        timedOut = true;
        cleanUp(script);
        console.error(`Tweet ${tweetID} embedding timed out after ${TWEET_EMBED_TIMEOUT}ms`);
        if (onFailure) {
            onFailure('timeout', tweetID);
        }
    }, TWEET_EMBED_TIMEOUT);

    // Track timeout for global cleanup on page unload
    if (!Awful.tweetEmbedTimeouts) {
        Awful.tweetEmbedTimeouts = [];
    }
    Awful.tweetEmbedTimeouts.push(timeoutId);

    window[callback] = function(data) {
        if (timedOut) {
            console.warn(`Ignoring late response for tweet ${tweetID}`);
            return;
        }

        clearTimeout(timeoutId);
        cleanUp(script);

        // Validate response - check for data existence but don't inspect HTML content (iframe issues)
        if (!data || !data.html || data.error) {
            console.error(`Tweet ${tweetID} API returned error:`, data ? data.error : 'No data');
            if (onFailure) {
                onFailure('api_error', tweetID, data);
            }
            return;
        }

        // Success
        if (onSuccess) {
            onSuccess(data, tweetID);
        }
    };

    script.onerror = function() {
        if (timedOut) return;
        cleanUp(this);
        console.error(`Tweet ${tweetID} network error`);
        if (onFailure) {
            onFailure('network', tweetID);
        }
    };

    function cleanUp(script) {
        clearTimeout(timeoutId);
        delete window[callback];
        if (script.parentNode) {
            script.parentNode.removeChild(script);
        }
    }

    document.body.appendChild(script);

    return { cleanup: function() { cleanUp(script); } };
};

/**
 * Embeds tweets within a specific post element using Twitter's OEmbed API.
 * Called by IntersectionObserver when a post enters the viewport.
 *
 * @param {Element} thisPostElement - The post element to process for tweet embeds
 */
Awful.embedTweetNow = function(thisPostElement) {
    // Check if already processing or processed
    if (thisPostElement.classList.contains("embed-processed") ||
        thisPostElement.classList.contains("embed-processing")) {
        return;
    }

    // Mark as processing to prevent duplicate IntersectionObserver calls during embedding
    thisPostElement.classList.add("embed-processing");

    const enableGhost = (window.Awful.renderGhostTweets == true);
    const tweetLinks = thisPostElement.querySelectorAll('a[data-tweet-id]');

    if (tweetLinks.length == 0) {
        // No tweets to embed, mark as processed immediately
        thisPostElement.classList.remove("embed-processing");
        thisPostElement.classList.add("embed-processed");
        return;
    }

    // Group tweet links by ID for deduplication
    const tweetIDsToLinks = {};
    Array.prototype.forEach.call(tweetLinks, function(a) {
        // Skip tweets with NWS content (use optional chaining to avoid null reference errors)
        if (a.parentElement?.querySelector('img.awful-smile[title=":nws:"]')) {
            return;
        }
        const tweetID = a.dataset.tweetId;
        if (!(tweetID in tweetIDsToLinks)) {
            tweetIDsToLinks[tweetID] = [];
        }
        tweetIDsToLinks[tweetID].push(a);
    });

    // Track completion of tweets in this post - only mark as processed when ALL complete
    let pendingTweets = Object.keys(tweetIDsToLinks).length;

    function markTweetComplete() {
        pendingTweets--;
        if (pendingTweets === 0) {
            // All tweets done (success or failure) - now safe to mark as processed
            thisPostElement.classList.remove("embed-processing");
            thisPostElement.classList.add("embed-processed");
        }
    }

    // Fetch and embed each unique tweet using shared helper function
    Object.keys(tweetIDsToLinks).forEach(function(tweetID) {
        const tweetLinks = tweetIDsToLinks[tweetID];

        // Get first link's URL for error messages
        const firstLink = tweetLinks[0];
        const tweetURL = firstLink ? firstLink.href : '';

        Awful.fetchTweetOEmbed(
            tweetID,
            // onSuccess callback
            function(data, tweetID) {
                // Replace all links for this tweet with embedded HTML
                tweetIDsToLinks[tweetID].forEach(function(a) {
                    if (a.parentNode) {
                        const div = document.createElement('div');
                        div.classList.add('tweet');
                        div.innerHTML = data.html;
                        a.parentNode.replaceChild(div, a);
                    }
                });

                // Load Twitter widgets (with race condition fix)
                Awful.loadTwitterWidgetsForEmbeds();

                // Mark this tweet as complete
                markTweetComplete();
            },
            // onFailure callback
            function(reason, tweetID) {
                // Show dead tweet badge for all links with this tweet ID
                tweetIDsToLinks[tweetID].forEach(function(a) {
                    if (a.parentNode) {
                        Awful.showDeadTweetBadge(tweetID, tweetURL, a);
                    }
                });

                // Mark this tweet as complete (even though it failed)
                markTweetComplete();
            }
        );
    });
};

/**
 Callback for fetchOEmbed.
 
 @param id The value for the `id` key in the message body.
 @param response An object with either a `body` key with the JSON response, or an `error` key explaining a failure.
 */
Awful.didFetchOEmbed = function(id, response) {
  waitingOEmbedResponses[id]?.(response);
};
var waitingOEmbedResponses = {};


/**
 Turns apparent links to Bluesky posts into actual embedded Bluesky posts.
 */
Awful.embedBlueskyPosts = function() {
  for (const a of document.querySelectorAll('a[data-bluesky-post]')) {
    (async function() {
      const search = new URLSearchParams();
      search.set('url', a.href);
      const url = `https://embed.bsky.app/oembed?${search}`;
      try {
        const oembed = await Awful.fetchOEmbed(url);
        if (!oembed.html) {
          return;
        }
        const div = document.createElement('div');
        div.classList.add('bluesky-post');
        div.innerHTML = oembed.html;
        a.parentNode.replaceChild(div, a);
        // <script> inserted via innerHTML won't execute, but we want whatever Bluesky script to run so it fetches the post content, so clone all <script>s.
        for (const scriptNode of div.querySelectorAll('script')) {
          const newScript = document.createElement('script');
          newScript.text = scriptNode.innerHTML;
          const attributes = scriptNode.attributes;
          for (let i = 0, len = attributes.length; i < len; i++) {
            newScript.setAttribute(attributes[i].name, attributes[i].value);
          }
          scriptNode.parentNode.replaceChild(newScript, scriptNode);
        }
      } catch (error) {
        console.error(`Could not fetch OEmbed from ${url}: ${error}`);
      }
    })();
  }
};

/**
 * Initializes lazy-loading tweet embeds using IntersectionObserver.
 * Tweets are embedded as posts enter the viewport (with a 600px lookahead).
 * Also sets up Lottie animation play/pause for ghost tweets in the viewport.
 */
Awful.embedTweets = function() {
  // Prevent concurrent setup to avoid race conditions where multiple calls could
  // create duplicate observers and listeners. The flag is reset in the finally block
  // to ensure it's always cleared even if errors occur.
  if (Awful.embedTweetsInProgress) {
    return;
  }
  Awful.embedTweetsInProgress = true;

  try {
    // Clean up any existing observers/timers before setting up new ones
    // This handles the case where embedTweets() is called multiple times on the same page
    Awful.cleanupObservers();

    Awful.loadTwitterWidgets();
    const enableGhost = (window.Awful.renderGhostTweets == true);

  // Set up IntersectionObserver for ghost Lottie animations (play/pause on scroll)
  if (enableGhost) {
    // Disconnect previous observer if it exists (prevents memory leak on re-render)
    if (Awful.ghostLottieObserver) {
      Awful.ghostLottieObserver.disconnect();
    }

    const ghostConfig = {
      root: document.body.posts,
      rootMargin: '0px',
      threshold: 0.000001,
    };

    Awful.ghostLottieObserver = new IntersectionObserver(function(posts) {
      posts.forEach((post) => {
        const players = post.target.querySelectorAll(SELECTORS.LOTTIE_PLAYERS);
        players.forEach((lottiePlayer) => {
          if (post.isIntersecting) {
            lottiePlayer.play();
          } else {
            lottiePlayer.pause();
          }
        });
      });
    }, ghostConfig);

    const postElements = document.querySelectorAll(SELECTORS.POST_ELEMENTS);
    postElements.forEach((post) => {
      Awful.ghostLottieObserver.observe(post);
    });
  }

  // Image loading and retry handling (works regardless of ghost feature being enabled)
  Awful.applyTimeoutToLoadingImages();
  Awful.setupRetryHandler();
  Awful.setupLazyImageErrorHandling();

  // Tweet retry handling
  Awful.setupTweetRetryHandler();

  // Set up lazy-loading IntersectionObserver for tweet embeds
  // Tweets are loaded before entering the viewport based on LAZY_LOAD_LOOKAHEAD_DISTANCE
  // Disconnect previous observer if it exists (prevents memory leak on re-render)
  if (Awful.tweetLazyLoadObserver) {
    Awful.tweetLazyLoadObserver.disconnect();
  }

  const lazyLoadConfig = {
    root: null,
    rootMargin: `${LAZY_LOAD_LOOKAHEAD_DISTANCE} 0px`,
    threshold: 0.000001,
  };

  Awful.tweetLazyLoadObserver = new IntersectionObserver(function(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        Awful.embedTweetNow(entry.target);
      }
    });
  }, lazyLoadConfig);

  // Observe all post elements for lazy loading
  const posts = document.querySelectorAll(SELECTORS.POST_ELEMENTS);
  posts.forEach((post) => {
    Awful.tweetLazyLoadObserver.observe(post);
  });

  // Notify native side when tweets are loaded
  if (window.twttr) {
    twttr.ready(function() {
      if (webkit.messageHandlers.didFinishLoadingTweets) {
        twttr.events.bind('loaded', function() {
          webkit.messageHandlers.didFinishLoadingTweets.postMessage({});
        });
      }
    });
  }

  } finally {
    // Always reset flag, even if an error occurs
    Awful.embedTweetsInProgress = false;
  }
};

// Image load progress tracker
Awful.imageLoadTracker = {
    loaded: 0,
    total: 0,

    initialize: function(totalCount) {
        this.loaded = 0;
        this.total = totalCount;
        this.reportProgress(); // Always report - Swift side handles zero case correctly
    },

    incrementLoaded: function() {
        this.loaded++;
        this.reportProgress();
    },

    reportProgress: function() {
        if (window.webkit?.messageHandlers?.imageLoadProgress) {
            webkit.messageHandlers.imageLoadProgress.postMessage({
                loaded: this.loaded,
                total: this.total,
                complete: this.loaded >= this.total
            });
        }
    }
};

/**
 * Apply timeout detection to images that are loading normally (first 10).
 * Monitors initial image loading and tracks progress for the loading view.
 */
Awful.applyTimeoutToLoadingImages = function() {
    const enableGhost = Awful.renderGhostTweets || false;

    // Find post content images (excluding smilies, avatars, and lazy-loaded images) - these are the first 10 images
    const loadingImages = document.querySelectorAll(SELECTORS.LOADING_IMAGES);

    // Count only the initially loading images (first 10), excluding attachment.php and data URLs
    const initialImages = Array.from(loadingImages).filter(img =>
        !img.src.includes('attachment.php') && !img.src.startsWith('data:')
    );
    const totalImages = initialImages.length;

    Awful.imageLoadTracker.initialize(totalImages);

    // Clear all existing timers before resetting array to prevent orphaned intervals
    if (Awful.imageTimeoutCheckers) {
        Awful.imageTimeoutCheckers.forEach(timer => clearInterval(timer));
    }
    Awful.imageTimeoutCheckers = [];

    initialImages.forEach((img, index) => {
        const imageID = `img-init-${index}`;
        const imageURL = img.src;

        // img.complete is true for both successfully loaded AND failed images
        // We discriminate using naturalHeight: >0 means success, ===0 means failure
        if (img.complete && img.naturalHeight !== 0) {
            Awful.imageLoadTracker.incrementLoaded();
            return;
        }

        // Track if we've already handled this image to prevent double-counting
        let handled = false;

        const handleSuccess = () => {
            if (handled) {
                console.warn(`[Image Load] Duplicate success event for ${imageID} (already handled)`);
                return;
            }
            handled = true;
            Awful.imageLoadTracker.incrementLoaded();
        };

        const handleFailure = () => {
            if (handled) {
                console.warn(`[Image Load] Duplicate failure event for ${imageID} (already handled)`);
                return;
            }
            handled = true;

            if (enableGhost && img.parentNode) {
                const div = document.createElement('div');
                div.classList.add('dead-embed-container');
                div.innerHTML = Awful.deadImageBadgeHTML(imageURL, imageID);
                img.parentNode.replaceChild(div, img);

                // Use helper function to set up Lottie player (fixes code duplication)
                Awful.setupGhostLottiePlayer(div);
            }

            Awful.imageLoadTracker.incrementLoaded();
        };

        // Set up timeout checker using config constants
        let checkCount = 0;
        const maxChecks = IMAGE_LOAD_TIMEOUT_CONFIG.maxImageChecks;
        const checkInterval = IMAGE_LOAD_TIMEOUT_CONFIG.connectionTimeout;

        const timeoutChecker = setInterval(() => {
            checkCount++;

            // If image loaded successfully
            // Note: img.complete is true for both success and failure
            // naturalHeight > 0 indicates successful load
            if (img.complete && img.naturalHeight !== 0) {
                clearInterval(timeoutChecker);
                handleSuccess();
                return;
            }

            // If image failed to load (error state)
            // img.complete true + naturalHeight === 0 indicates load failure
            if (img.complete && img.naturalHeight === 0) {
                clearInterval(timeoutChecker);
                handleFailure();
                return;
            }

            // If we've checked enough times and it's still not loaded, timeout
            if (checkCount >= maxChecks) {
                clearInterval(timeoutChecker);
                handleFailure();
            }
        }, checkInterval);

        // Store timer for potential cleanup
        Awful.imageTimeoutCheckers.push(timeoutChecker);

        // Also listen for load/error events to handle immediately
        img.addEventListener('load', () => {
            clearInterval(timeoutChecker);
            handleSuccess();
        }, { once: true });

        img.addEventListener('error', () => {
            clearInterval(timeoutChecker);
            handleFailure();
        }, { once: true });
    });
};

/**
 * Setup retry click handler (using event delegation) - call once on page load.
 * Allows users to retry loading failed images.
 */
Awful.setupRetryHandler = function() {
    // Remove old event listener if it exists (prevents memory leak on page re-render)
    if (Awful.retryClickHandler) {
        document.removeEventListener('click', Awful.retryClickHandler);
    }

    // Define handler function and store reference for cleanup
    Awful.retryClickHandler = function(event) {
        const retryLink = event.target;
        if (retryLink.hasAttribute('data-retry-image')) {
            event.preventDefault();

            const imageURL = retryLink.getAttribute('data-retry-image');
            const container = retryLink.closest('.dead-embed-container');

            if (container) {
                // Update retry link to show "Retrying..." state
                retryLink.textContent = 'Retrying...';
                retryLink.style.pointerEvents = 'none';  // Disable clicking during retry

                // Create new image element with native browser loading
                const successImg = document.createElement('img');
                successImg.setAttribute('alt', '');

                // Handle successful load
                successImg.addEventListener('load', () => {
                    // Replace the dead badge container with the successful image
                    container.parentNode.replaceChild(successImg, container);
                }, { once: true });

                // Handle load failure
                successImg.addEventListener('error', (error) => {
                    // FAILED - restore retry button with "Failed" feedback
                    console.error(`Retry failed: ${error.message || 'Unknown error'} - ${imageURL}`);

                    retryLink.textContent = 'Retry Failed - Try Again';
                    retryLink.style.pointerEvents = 'auto';  // Re-enable clicking

                    // Reset to just "Retry" after configured delay
                    setTimeout(() => {
                        if (retryLink.textContent === 'Retry Failed - Try Again') {
                            retryLink.textContent = 'Retry';
                        }
                    }, IMAGE_LOAD_TIMEOUT_CONFIG.retryResetDelay);
                }, { once: true });

                // Start loading (native browser handles everything)
                successImg.src = imageURL;
            }
        }
    };

    // Register the event listener with stored reference
    document.addEventListener('click', Awful.retryClickHandler, { once: false });
};

/**
 * Sets up a click event listener for retrying failed tweet embeds.
 * Uses shared fetchTweetOEmbed helper for consistent timeout and error handling.
 */
Awful.setupTweetRetryHandler = function() {
    // Remove old event listener if it exists (prevents memory leak on page re-render)
    if (Awful.tweetRetryClickHandler) {
        document.removeEventListener('click', Awful.tweetRetryClickHandler);
    }

    // Define handler function and store reference for cleanup
    Awful.tweetRetryClickHandler = function(event) {
        const button = event.target;
        if (button.hasAttribute('data-retry-tweet')) {
            event.preventDefault();

            const tweetID = button.getAttribute('data-retry-tweet');
            const tweetURL = button.getAttribute('data-tweet-url');
            const deadContainer = button.closest('.dead-tweet-container');

            if (!deadContainer || !deadContainer.parentNode) {
                return;
            }

            // Validate URL is actually a Twitter/X URL (security check)
            if (!tweetURL.match(/^https?:\/\/(www\.)?(twitter\.com|x\.com)\//)) {
                console.error('Invalid tweet URL for retry:', tweetURL);
                return;
            }

            // Disable button during retry
            button.disabled = true;
            button.textContent = 'Retrying...';

            // Create loading indicator
            const loadingDiv = document.createElement('div');
            loadingDiv.className = 'tweet-loading';
            loadingDiv.textContent = 'Loading tweet...';
            deadContainer.parentNode.replaceChild(loadingDiv, deadContainer);

            // Use shared fetch function
            Awful.fetchTweetOEmbed(
                tweetID,
                // onSuccess
                function(data, tweetID) {
                    if (loadingDiv.parentNode) {
                        const div = document.createElement('div');
                        div.classList.add('tweet');
                        div.innerHTML = data.html;
                        loadingDiv.parentNode.replaceChild(div, loadingDiv);

                        // Load Twitter widgets (using shared function)
                        Awful.loadTwitterWidgetsForEmbeds();
                    }
                },
                // onFailure
                function(reason, tweetID) {
                    // Show dead badge again using shared function
                    if (loadingDiv.parentNode) {
                        Awful.showDeadTweetBadge(tweetID, tweetURL, loadingDiv);
                    }
                }
            );
        }
    };

    // Register the event listener with stored reference
    document.addEventListener('click', Awful.tweetRetryClickHandler, { once: false });
};

/**
 * Cleanup function to remove retry click handler and prevent memory leaks.
 * Should be called when the view is destroyed or navigating away from the page.
 */
Awful.cleanupRetryHandler = function() {
    if (Awful.retryClickHandler) {
        document.removeEventListener('click', Awful.retryClickHandler);
        Awful.retryClickHandler = null;
    }
};

/**
 * Sets up error handling for lazy-loaded images (those with loading="lazy" attribute).
 * Attaches error event listeners that display dead image badges when browser attempts
 * to load the image and it fails (404, broken, etc.). Only triggers after browser
 * attempts load - doesn't interfere with native lazy loading.
 */
Awful.setupLazyImageErrorHandling = function() {
    const enableGhost = Awful.renderGhostTweets || false;
    const lazyImages = document.querySelectorAll('section.postbody img[loading="lazy"]');

    lazyImages.forEach((img, index) => {
        const imageID = `lazy-error-${index}`;

        // Only attach error listener - don't interfere with lazy loading
        img.addEventListener('error', function() {
            // Browser attempted to load this image and it failed
            const imageURL = img.src;
            Awful.handleImageLoadError(
                new Error("Lazy image load failed"),
                imageURL,
                img,
                imageID,
                enableGhost,
                false // trackProgress = false, lazy images don't count toward progress
            );
        }, { once: true });
    });
};

/**
 * Cleanup function to clear all image timeout interval timers.
 * Prevents timers from running after page navigation or view destruction.
 */
Awful.cleanupImageTimers = function() {
    if (Awful.imageTimeoutCheckers) {
        Awful.imageTimeoutCheckers.forEach(timer => clearInterval(timer));
        Awful.imageTimeoutCheckers = [];
    }
};

/**
 * Cleanup function to clear all tweet embedding timeout timers.
 * Prevents timers from running after page navigation or view destruction.
 */
Awful.cleanupTweetTimers = function() {
    if (Awful.tweetEmbedTimeouts) {
        Awful.tweetEmbedTimeouts.forEach(function(timeoutId) {
            clearTimeout(timeoutId);
        });
        Awful.tweetEmbedTimeouts = [];
    }
};

/**
 * Cleanup function to disconnect all IntersectionObservers and prevent memory leaks.
 * Should be called when the view is destroyed or navigating away from the page.
 */
Awful.cleanupObservers = function() {
    if (Awful.ghostLottieObserver) {
        Awful.ghostLottieObserver.disconnect();
        Awful.ghostLottieObserver = null;
    }
    if (Awful.tweetLazyLoadObserver) {
        Awful.tweetLazyLoadObserver.disconnect();
        Awful.tweetLazyLoadObserver = null;
    }

    Awful.cleanupImageTimers();
    Awful.cleanupTweetTimers();
};

Awful.tweetTheme = function() {
  return document.body.dataset.tweetTheme;
}

Awful.setTweetTheme = function(newTheme) {
  document.body.dataset.tweetTheme = newTheme;
}


/**
 Loads Twitter's widgets.js into the document. In the meantime, makes `window.twttr.ready()` available so you can prepare a callback for when widgets.js finishes loading:

     twttr.ready(function() {
       alert("widgets.js has loaded (or was already loaded)");
     });

 It's ok to call this function multiple times. It only loads widgets.js once.
 */
Awful.loadTwitterWidgets = function() {
  if (document.getElementById('twitter-wjs')) {
    return;
  }

  var script = document.createElement('script');
  script.id = 'twitter-wjs';
  script.src = "https://platform.twitter.com/widgets.js";

  // Add error handler for widgets.js load failure
  script.onerror = function() {
    console.error('Failed to load Twitter widgets.js');
    // Set flag to prevent queuing more callbacks
    if (window.twttr) {
      window.twttr._failed = true;
    }
  };

  document.body.appendChild(script);

  window.twttr = {
    _e: [],
    _failed: false,  // Track load failure
    ready: function(f) {
      if (window.twttr._failed) {
        console.warn('Twitter widgets.js failed to load, skipping callback');
        return;
      }
      twttr._e.push(f);
    }
  };
};


/**
 Scrolls the document past a fraction of the document.

 @param {number} fraction - A number between 0 and 1, where 0 is the top of the document and 1 is the bottom.
 */
Awful.jumpToFractionalOffset = function(fraction) {
  window.scroll(0, document.body.scrollHeight * fraction);
};


/**
 Handles any click event, including:

     * Loading linkified images.
     * Revealing spoilers.

 @param {Event} event - A click event.
 */
Awful.handleClickEvent = function(event) {

  // We'll be using this in a couple places.
  var gifWrapper = event.target.closest('.gif-wrap');

  // Toggle spoilers on tap.
  var spoiler = event.target.closest('.bbc-spoiler');
  if (spoiler) {
    var isSpoiled = spoiler.classList.contains('spoiled');

    if (isSpoiled && gifWrapper) {
      Awful.toggleGIF(gifWrapper);
      event.preventDefault();
      return;
    }

    var nearestLink = event.target.closest('a, [data-awful-linkified-image]');
    var isLink = !!nearestLink;

    if (!(isLink && isSpoiled)) {
        spoiler.classList.toggle("spoiled");
        event.preventDefault();
    } else if (isLink && !isSpoiled) {
        event.preventDefault();
    }
    return;
  }

  // Show linkified images on tap.
  var link = event.target;
  if (link.hasAttribute('data-awful-linkified-image')) {
    var img = document.createElement('img');
    img.setAttribute('alt', "");
    img.setAttribute('border', "0");
    img.setAttribute('src', link.textContent);

    link.parentNode.replaceChild(img, link);

    event.preventDefault();
    return;
  }

  // Tap on poster's username or avatar to reveal actions on the poster.
  var usernameOrAvatar = event.target.closest('.username, .avatar');
  var didTapAuthorHandler = window.webkit.messageHandlers.didTapAuthorHeader;
  if (usernameOrAvatar && didTapAuthorHandler) {
    var postIndex = Awful.postIndexOfElement(usernameOrAvatar);
    if (postIndex !== null) {
      var frame = Awful.frameOfElement(usernameOrAvatar);
      didTapAuthorHandler.postMessage({
          "frame": frame,
          "postIndex": postIndex
      });

      event.preventDefault();
      return;
    }
  }

  // Tap on action button to reveal actions on the post.
  var button = event.target.closest('button.action-button');
  var postIndex;
  if (button && (postIndex = Awful.postIndexOfElement(button)) !== null) {
    var frame = Awful.frameOfElement(button);

    window.webkit.messageHandlers.didTapPostActionButton.postMessage({
        "frame": frame,
        "postIndex": postIndex
    });

    event.preventDefault();
    return;
  }

  // Tap a gif-wrapper to toggle playing the gif.
  if (gifWrapper) {
    Awful.toggleGIF(gifWrapper);
    event.preventDefault();
    return;
  }
};


/**
 An element's frame in web view coordinates.
 @typedef ElementRect
 @type {object}
 @property {number} x - The horizontal component of the rectangle's origin.
 @property {number} y - The vertical component of the rectangle's origin.
 @property {number} width - The width of the rectangle.
 @property {number} height - The height of the rectangle.
 */


/**
 Returns the frame of an element in the web view's coordinate system.

 @param {Element} element - An element in the document.
 @returns {ElementRect} The element's frame, or a rectangle with zero area if the element's border boxes are all empty.
 */
Awful.frameOfElement = function(element) {
  var rect = element.getBoundingClientRect();
  return {
    "x": rect.left,
    "y": rect.top,
    "width": rect.width,
    "height": rect.height
  };
};


/**
 Machinery to show and periodically refresh a "flag" image at the top of the page. Since these seem limited to FYAD, we call them FYAD flags. The actual fetching gets done on the native-side for CORS reasons. Since there's a few functions and a couple properties involved, we'll store them in a handy object.
 */
Awful.fyadFlag = {
  fetchFlag: function() {
    window.webkit.messageHandlers.fyadFlagRequest.postMessage({});
  },

  setFlag: function(flag) {
    if (flag.src && flag.title) {
      var img = document.createElement('img');
      img.setAttribute('src', flag.src);
      img.setAttribute('title', flag.title);

      var div = document.getElementById('fyad-flag');
      if (!div) {
        div = document.createElement('div');
        div.setAttribute('id', 'fyad-flag');
        document.getElementById('posts').insertAdjacentElement('afterbegin', div);
      }

      while (div.firstChild) {
        div.firstChild.remove();
      }
      div.appendChild(img);

      Awful.fyadFlag.timer = setTimeout(Awful.fyadFlag.fetchFlag, 60000);

    } else if (Awful.fyadFlag.didStart) {
      console.log("did not receive an FYAD flag; will retry later");

      Awful.fyadFlag.timer = setTimeout(Awful.fyadFlag.fetchFlag, 60000);
    }
  },

  startFetching: function() {
    Awful.fyadFlag.didStart = true;

    Awful.fyadFlag.fetchFlag();
  }
};


/**
 Starts/stops a wrapped GIF playing.

 @param {Element} gifWrapper - An element wrapping a GIF.
 */
Awful.toggleGIF = function(gifWrapper) {
  var img = gifWrapper.querySelector('img.posterized');
  if (!img) { return; }

  if (gifWrapper.classList.contains('playing')) {
    var posterURL = img.getAttribute('data-poster-url');
    var gifURL = img.getAttribute('src');

    gifWrapper.classList.remove('playing');
    img.setAttribute('data-original-url', gifURL);
    img.setAttribute('src', posterURL);
  } else if (gifWrapper.classList.contains('loading')) {
    // Just wait for the load to happen.
  } else {
    gifWrapper.classList.add('loading');

    var posterURL = img.getAttribute('src');
    var gifURL = img.getAttribute('data-original-url');

    var cacheWarmer = document.createElement('img');
    cacheWarmer.onload = function() {
      img.setAttribute('src', gifURL);
      img.setAttribute('data-poster-url', posterURL);
      gifWrapper.classList.add('playing');
      gifWrapper.classList.remove('loading');
    };
    cacheWarmer.onerror = function() {
      img.classList.remove('loading');
    };
    cacheWarmer.src = gifURL;
  }
};


/**
 Returns a rectangle (in the web view's coordinate system) that encompasses each frame of the provided elements.

 @param {Element[]|NodeList} elements - An array or a NodeList of elements.
 @returns {ElementRect} A frame that encompasses all of the elements, or null if elements is empty.
 */
Awful.unionFrameOfElements = function(elements) {
  var union = null;
  Array.prototype.forEach.call(elements, function(el) {
    var rect = Awful.frameOfElement(el);

    if (!union) {
      union = rect;
      return;
    }

    var left = Math.min(rect.x, union.x);
    var top = Math.min(rect.y, union.y);
    var right = Math.max(rect.x + rect.width, union.x + union.width);
    var bottom = Math.max(rect.y + rect.height, union.y + union.height);
    union = {
      "x": left,
      "y": top,
      "width": right - left,
      "height": bottom - top
    };
  });

  return union;
};


/**
 @typedef InterestingLink
 @type {object}
 @property {ElementRect} frame - Where the link is in web view coordinates.
 @property {string} url - The interesting link's destination.
*/

/**
 Interesting things in the webview. May have none, some, or all of its properties populated.
 @typedef InterestingElements
 @type {object}
 @property {boolean} [hasUnspoiledLink] - true when there's an unspoiled link we shouldn't inadvertently reveal.
 @property {string} [postContainerElement] - One of "header", "postbody", "footer" depending on where the element is within the post. For example, a user's avatar will have this set to "header".
 @property {ElementRect} [spoiledImageFrame] - Where the image is in web view coordinates.
 @property {string} [spoiledImageTitle] - The title of an image visible to the user. For smilies, contains the text used to insert the smilie into a post.
 @property {string} [spoiledImageURL] - A URL pointing to an image that's visible to the user.
 @property {InterestingLink} [spoiledLink] - A text link visible to the user.
 @property {InterestingLink} [spoiledVideo] - A video embed visible to the user.
 */

/**
 @param {number} x - The x coordinate of the point of curiosity, in web view coordinates.
 @param {number} y - The y coordinate of the point of curiosity, in web view coordinates.
 @returns {InterestingElements} Anything interesting found at the given point that may warrant further interaction.
 */
Awful.interestingElementsAtPoint = function(x, y) {
  var interesting = {};
  var elementAtPoint = document.elementFromPoint(x, y);
  if (!elementAtPoint) {
    return interesting;
  }

  if (elementAtPoint.closest('header')) {
    interesting.postContainerElement = 'header';
  } else if (elementAtPoint.closest('section.postbody')) {
    interesting.postContainerElement = 'postbody';
  } else if (elementAtPoint.closest('footer')) {
    interesting.postContainerElement = 'footer';
  }

  var img = elementAtPoint.closest('img:not(button img)');
  if (img && Awful.isSpoiled(img)) {
    interesting.spoiledImageTitle = img.getAttribute('title');
    if (img.classList.contains('posterized')) {
      interesting.spoiledImageURL = img.dataset.originalUrl;
    } else {
      interesting.spoiledImageURL = img.getAttribute('src');
    }
    interesting.spoiledImageFrame = Awful.frameOfElement(img);
  }

  var a = elementAtPoint.closest('a[href]');
  if (a) {
    if (Awful.isSpoiled(a)) {
      interesting.spoiledLink = {
        frame: Awful.frameOfElement(a),
        url: a.getAttribute('href')
      };
    } else {
      interesting.hasUnspoiledLink = true;
    }
  }

  var video = elementAtPoint.closest('iframe[src], video[src]');
  if (video && Awful.isSpoiled(video)) {
    var src = video.getAttribute('src');
    if (src) {
      interesting.spoiledVideo = {
        frame: Awful.frameOfElement(video),
        url: src
      };
    }
  }

  return interesting;
};


/**
 @returns {boolean} true when the element (or any ancestor) is unspoiled; that is, the element is visible to the user and is not hidden behind spoiler bars.
 */
Awful.isSpoiled = function(element) {
  var spoiler = element.closest('.bbc-spoiler');
  return !spoiler || spoiler.classList.contains('spoiled');
};


/**
 Scrolls the identified post into view.
 */
Awful.jumpToPostWithID = function(postID) {
  // If we previously jumped to this post, we need to clear the hash in order to jump again.
  window.location.hash = "";

  window.location.hash = `#${postID}`;
};


/**
 Returns the web view frame of the post at (x, y) in web view coordinates.
 */
Awful.postElementAtPoint = function(x, y) {
    var elementAtPoint = document.elementFromPoint(x, y);
    var postElement = elementAtPoint && elementAtPoint.closest('post');
    return postElement ? Awful.frameOfElement(postElement) : null;
};


/**
 Turns all links with `data-awful-linkified-image` attributes into img elements.
 */
Awful.loadLinkifiedImages = function() {
  var links = document.querySelectorAll('[data-awful-linkified-image]');
  Array.prototype.forEach.call(links, function(link) {
    var url = link.textContent;
    var img = document.createElement('img');
    img.setAttribute('alt', "");
    img.setAttribute('border', '0');
    img.setAttribute('src', url);
    link.parentNode.replaceChild(img, link);
  });
};


/**
 Marks as read all posts up to and including the identified post.
 */
Awful.markReadUpToPostWithID = function(postID) {
  var lastReadPost = document.getElementById(postID);
  if (!lastReadPost) { return; }

  // Go backward, marking as seen.
  var currentPost = lastReadPost;
  while (currentPost) {
    currentPost.classList.add('seen');
    currentPost = currentPost.previousElementSibling;
  }

  // Go forward, marking as unseen.
  var currentPost = lastReadPost.nextElementSibling;
  while (currentPost) {
    currentPost.classList.remove('seen');
    currentPost = currentPost.nextElementSibling;
  }
};


/**
 Returns the index of the post that contains the element, if any. The element can be a `<post>` element or appear in any subtree of a `<post>` element.

 @param {Element} element - An element in the document.
 @returns {?number} The index of the post where `element` appears, where `0` is the first post in the document; or `null` if `element` is not in a `<post>` element.
 */
Awful.postIndexOfElement = function(element) {
  var post = element.closest('post');
  if (!post) {
    return null;
  }

  var i = 0;
  var curr = post.previousElementSibling;
  while (curr) {
    if (curr.nodeName === "POST") {
      i += 1;
    }
    curr = curr.previousElementSibling;
  }

  return i;
};


/**
 Adds some posts to the top of the #posts element.
 */
Awful.prependPosts = function(postsHTML) {
  var oldHeight = document.documentElement.scrollHeight;

  document.getElementById('posts').insertAdjacentHTML('afterbegin', postsHTML);

  if (window.twttr) {
    window.twttr.ready(function() {
      Awful.embedTweets();
    });
  }

  var newHeight = document.documentElement.scrollHeight;
  window.scrollBy(0, newHeight - oldHeight);
};


/**
 Replaces the announcement HTML.

 @param {string} html - The updated HTML for the announcement.
 */
Awful.setAnnouncementHTML = function(html) {
  var post = document.querySelector('post');
  if (post) {
    post.remove();
  }

  document.body.insertAdjacentHTML('beforeend', html);
};


Awful.deadTweetBadgeHTML = function(url, tweetID){
    // Sanitize URL to prevent XSS attacks
    const safeURL = Awful.sanitizeURL(url);

    // get twitter username from url (with fallback for malformed URLs)
    let tweeter = 'unknown';
    try {
        const match = url.match(/(?:https?:\/\/)?(?:www\.)?twitter\.com\/(?:#!\/)?@?([^\/\?\s]*)/);
        if (match && match[1]) {
            tweeter = Awful.escapeHTML(match[1]);
        }
    } catch (e) {
        console.error('Error parsing tweet URL:', e);
    }

    // Escape tweetID for use in HTML attributes
    const safeTweetID = Awful.escapeHTML(tweetID);

    var html =
    `<div class="ghost-lottie">
            <lottie-player id="left-ghost-${safeTweetID}" class="left-ghost-${safeTweetID}" background="transparent" speed="1" loop autoplay>
            </lottie-player>
     </div>
    <span class="dead-tweet-title">DEAD TWEET</span>
    <a class="dead-tweet-link" href="${safeURL}">@${tweeter}</a>
    <a class="dead-embed-retry" data-retry-tweet="${safeTweetID}" data-tweet-url="${safeURL}" href="#">Retry</a>
    `;

    return html;
};

// Dead Image Badge (similar to dead tweet)
Awful.deadImageBadgeHTML = function(url, imageID) {
    // Sanitize URL to prevent XSS attacks
    const safeURL = Awful.sanitizeURL(url);

    // Extract filename from URL and escape it
    let filename = 'unknown';
    try {
        const urlParts = url.split('/').pop().split('?')[0];
        if (urlParts) {
            filename = Awful.escapeHTML(urlParts);
        }
    } catch (e) {
        console.error('Error parsing image URL:', e);
    }

    // Escape imageID for use in HTML attributes
    const safeImageID = Awful.escapeHTML(imageID);

    var html =
    `<div class="ghost-lottie">
            <lottie-player id="image-ghost-${safeImageID}" class="image-ghost-${safeImageID}" background="transparent" speed="1" loop autoplay>
            </lottie-player>
     </div>
    <span class="dead-embed-title">DEAD IMAGE</span>
    <a class="dead-embed-link" href="${safeURL}">${filename}</a>
    <a class="dead-embed-retry" data-retry-image="${safeURL}" href="#">Retry</a>
    `;

    return html;
};


/**
 Sets the "dark" class on the `<body>` element.

 @param {boolean} `true` for dark mode, `false` for light mode.
 */
Awful.setDarkMode = function(dark) {
  document.body.classList.toggle('dark', dark);
};


/**
 Updates the externally-updatable stylesheet, which lets us make changes quickly without going through a full app update.
 */
Awful.setExternalStylesheet = function(stylesheet) {
  var externalStyle = document.getElementById('awful-external-style');
  if (externalStyle) {
    externalStyle.innerText = stylesheet;
  }
};


/**
 Updates the user-specified font scale setting.

 @param {number} percentage - The user's selected font scale as a percentage.
 */
Awful.setFontScale = function(percentage) {
  var style = document.getElementById('awful-font-scale-style');
  if (!style) {
    return;
  }

  if (percentage == 100) {
    style.textContent = '';
  } else {
    style.textContent = ".nameanddate, .postbody, footer { font-size: " + percentage + "%; }";
  }
};


/**
 Updates the user-specified setting to highlight the logged-in user's username whenever it occurs in posts.

 @param {boolean} highlightMentions - `true` to highlight the logged-in user's username, `false` to remove any such highlighting.
 */
Awful.setHighlightMentions = function(highlightMentions) {
  var mentions = document.querySelectorAll(".postbody span.mention");
  Array.prototype.forEach.call(mentions, function(mention) {
    mention.classList.toggle("highlight", highlightMentions);
  });
};


/**
 Updates the user-specified setting to highlight quote blocks that cite the logged-in user.

 @param {boolean} highlightQuotes - `true` to highlight quotes written by the user, `false` to remove any such highlighting.
 */
Awful.setHighlightQuotes = function(highlightQuotes) {
  var quotes = document.querySelectorAll(".bbc-block.mention");
  Array.prototype.forEach.call(quotes, function(quote) {
    quote.classList.toggle("highlight", highlightQuotes);
  });
};


/**
 Replaces a particular post's innerHTML.
 */
Awful.setPostHTMLAtIndex = function(postHTML, i) {
  // nth-of-type is 1-indexed, but the app uses 0-indexing.
  var post = document.querySelector(`post:nth-of-type(${i + 1})`);
  post.outerHTML = postHTML;
};


/**
 Updates the user-specified setting to show avatars.

 @param {boolean} showAvatars - `true` to show user avatars, `false` to hide user avatars.
 */
Awful.setShowAvatars = function(showAvatars) {
  if (showAvatars) {
    var headers = document.querySelectorAll('header[data-awful-avatar]');
    Array.prototype.forEach.call(headers, function(header) {
      var img = document.createElement('img');
      img.classList.add("avatar");
      img.setAttribute('alt', "");
      img.setAttribute('src', header.dataset.awfulAvatar);
      header.insertBefore(img, header.firstChild);

      header.removeAttribute('data-awful-avatar');

      var post = header.closest('post');
      if (post) {
        post.classList.remove("no-avatar");
      }
    });
  } else {
    var imgs = document.querySelectorAll('header img.avatar');
    Array.prototype.forEach.call(imgs, function(img) {
      var header = img.closest('header');
      if (header) {
        header.dataset.awfulAvatar = img.getAttribute('src');
      }

      var post = img.closest('post');
      if (post) {
        post.classList.add("no-avatar");
      }

      img.remove();
    });
      
    // hide custom titles, which replace avatars when enabled on ipad
    var customTitles = document.querySelectorAll('.customTitle');

    Array.prototype.forEach.call(customTitles, function(customTitle) {
        if (customTitle.classList.contains('hidden')) {
            customTitle.classList.remove('hidden')
        } else {
            customTitle.classList.add('hidden')
        }
    });
  }
};


/**
 Updates the stylesheet for the currently-selected theme.

 @param {string} css - The replacement stylesheet from the new theme.
 */
Awful.setThemeStylesheet = function(css) {
  var style = document.getElementById('awful-inline-style');
  if (!style) { return; }
  style.textContent = css;
};


document.body.addEventListener('click', Awful.handleClickEvent);


// Listen for taps on the profile screen's rows.
var contact = document.getElementById('contact');
if (contact) {
  contact.addEventListener('click', function(event) {
    var row = event.target.closest('tr');
    if (!row) { return; }
    var service = row.querySelector('th');
    if (!service) { return; }

    if (service.textContent === "Private Message") {
      webkit.messageHandlers.sendPrivateMessage.postMessage({});
      event.preventDefault();
    } else if (service.textContent === "Homepage") {
      var td = row.querySelector('td');
      if (!td) { return; }
      var url = td.textContent;
      webkit.messageHandlers.showHomepageActions.postMessage({
        frame: Awful.frameOfElement(row),
        url: url
      });
      event.preventDefault();
    }
  });
}


if (document.body.classList.contains('forum-26')) {
  Awful.fyadFlag.startFetching();
}

Awful.embedGfycat = function() {
  var postLinks = document.querySelectorAll('section.postbody a')

  Array.prototype.forEach.call(postLinks, function(link) {
    var vidInfo = matchVidLinkurl(link);
    if (vidInfo && isGfycatLink(link)) {
      var gifyKey = link.pathname.match(/([A-Za-z]+)(?:\/*)?/i);
      if (gifyKey) {
          fetch(`https://api.gfycat.com/v1/gfycats/${gifyKey[1]}`)
            .then(function(res) { res.json() })
            .then(function(l) {
              if (l.gfyItem) {
                  var div = document.createElement('div');
                  div.className = 'gifv_video';
                  div.innerHTML = gfyUrlToVideo(l.gfyItem.posterUrl, l.gfyItem.mp4Url);
                  link.replaceWith(div);
              }
            })
            .catch(console.warn); //ignore errors, keep processing
      }
    }
  });

  function matchVidLinkurl(link) {
    var match = link.pathname.match(/(\.gifv|\.webm|\.mp4)$/i);
    if (!match)
        return null;
    return {
        extension: match[1]
    };
  }
  function isGfycatLink(link) {
    return /gfycat.com$/i.test(link.hostname);
  }
  function gfyUrlToVideo(posterUrl, mp4Url) {
      return `<video width="320" playsinline webkit-playsinline preload="metadata" controls loop muted="true" poster="${posterUrl}"><source src="${mp4Url}" type="video/mp4"></video>`;
  }
}

Awful.embedGfycat();

// Set up image loading if DOM is ready (DOMContentLoaded may have already fired)
// The early user script in RenderView.swift tracks when DOMContentLoaded fires
if (Awful.domContentLoadedFired) {
    if (typeof Awful.applyTimeoutToLoadingImages === 'function') {
        Awful.applyTimeoutToLoadingImages();
        Awful.setupRetryHandler();
        Awful.setupLazyImageErrorHandling();
    }
} else {
    document.addEventListener('DOMContentLoaded', function() {
        if (typeof Awful.applyTimeoutToLoadingImages === 'function') {
            Awful.applyTimeoutToLoadingImages();
            Awful.setupRetryHandler();
            Awful.setupLazyImageErrorHandling();
        }
    });
}

// THIS SHOULD STAY AT THE BOTTOM OF THE FILE!
// All done; tell the native side we're ready.
window.webkit.messageHandlers.didRender.postMessage({});
