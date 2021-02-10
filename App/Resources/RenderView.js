//  RenderView.js
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// This file is loaded as a user script "at document end" into the `WKWebView` that renders announcements, posts, profiles, and private messages.

"use strict";

if (!window.Awful) {
    window.Awful = {};
}


/**
 Turns apparent links to tweets into actual embedded tweets.
 */
Awful.embedTweets = function() {
  Awful.loadTwitterWidgets();

  var tweetLinks = document.querySelectorAll('a[data-tweet-id]');
  if (tweetLinks.length == 0) {
    return;
  }

  var tweetIDsToLinks = {};
  Array.prototype.forEach.call(tweetLinks, function(a) {
    if (a.parentElement.querySelector('img.awful-smile[title=":nws:"]')) {
      return;
    }
    var tweetID = a.dataset.tweetId;
    if (!(tweetID in tweetIDsToLinks)) {
      tweetIDsToLinks[tweetID] = [];
    }
    tweetIDsToLinks[tweetID].push(a);
  });

  var totalFetchCount = Object.keys(tweetIDsToLinks).length;
  var completedFetchCount = 0;

  Object.keys(tweetIDsToLinks).forEach(function(tweetID) {
    var callback = `jsonp_callback_${tweetID}`;
    var tweetTheme = Awful.tweetTheme();

    var script = document.createElement('script');
    script.src = `https://api.twitter.com/1/statuses/oembed.json?id=${tweetID}&omit_script=true&dnt=true&theme=${tweetTheme}&callback=${callback}`;

    window[callback] = function(data) {
      cleanUp(script);

      tweetIDsToLinks[tweetID].forEach(function(a) {
        if (a.parentNode) {
          var div = document.createElement('div');
          div.classList.add('tweet');
          div.innerHTML = data.html;
          a.parentNode.replaceChild(div, a);
        }
      });

      didCompleteFetch();
    };

    script.onerror = function() {
      cleanUp(this);
      console.error(`The embed markup for tweet ${tweetID} failed to load`);
      didCompleteFetch();
    };

    function cleanUp(script) {
      delete window[callback];
      if (script.parentNode) {
        script.parentNode.removeChild(script);
      }
    }

    document.body.appendChild(script);
  });

  function didCompleteFetch() {
    completedFetchCount += 1;

    if (completedFetchCount == totalFetchCount) {
      if (window.twttr) {
        twttr.ready(function() {
          twttr.widgets.load();
        });

        if (webkit.messageHandlers.didFinishLoadingTweets) {
          twttr.events.bind('loaded', function() {
            webkit.messageHandlers.didFinishLoadingTweets.postMessage({});
          });
        }
      }
    }
  }
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
  document.body.appendChild(script);

  window.twttr = {
    _e: [],
    ready: function(f) {
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

  // Tap on post header to reveal actions on the poster.
  var header = event.target.closest('header');
  var didTapAuthorHandler = window.webkit.messageHandlers.didTapAuthorHeader;
  if (header && didTapAuthorHandler) {
    var postIndex = Awful.postIndexOfElement(header);
    if (postIndex !== null) {
      var frame = Awful.frameOfElement(header);
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
 Calculates getBoundingClientRect().top for the post AFTER the one being doubletapped.
 If it's the last post then the original y parameter is returned unchanged.
 Used to perform all calculations here, but window.scrollTo doesn't animate nicely. Even
 with 'smooth' behaviour.
 However, the calculations and scroll taking place here does result in a more precise action.
 But precision is not critical for this
 
 Block quote elements do not have a class, so needed to use tag instead.
 */
Awful.jumpToFooterOfCurrentPost = function(y) {
    var x = 0;
    var elementAtPoint = document.elementFromPoint(x, y);
    if (!elementAtPoint || (elementAtPoint.className != 'postbody' &&
                            elementAtPoint.tagName != 'BLOCKQUOTE')) {
      return y;
    }
    var postElement;
    if (elementAtPoint.tagName == 'BLOCKQUOTE'){
        postElement = elementAtPoint.parentNode.parentNode.parentNode;
    } else {
        postElement = elementAtPoint.parentNode;
    }
        var threadElement = postElement.parentNode;
        var allPosts = threadElement.getElementsByTagName('post');
        var numberOfPosts = allPosts.length;
        var postID = postElement.id;
        var lastPostID = allPosts[allPosts.length - 1].id;
  
        if (postID != lastPostID){
            var nextPost = postElement.nextElementSibling;
            var nextPostID = nextPost.id;
            y = nextPost.getBoundingClientRect().top;
        }
    
    return y;
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
// THIS SHOULD STAY AT THE BOTTOM OF THE FILE!
// All done; tell the native side we're ready.
window.webkit.messageHandlers.didRender.postMessage({});
