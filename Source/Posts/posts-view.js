// Assumes common.js is available.

// Storage for a couple globals.
window.Awful = {};

startBridge(function(bridge) {
  bridge.init();
  
  bridge.registerHandler('changeStylesheet', function(css) {
    $('#awful-inline-style').text(css);
  });
  
  bridge.registerHandler('changeExternalStylesheet', function(css) {
    $('#awful-external-style').text(css);
  });
  
  bridge.registerHandler('fontScale', function(scalePercentage) {
    fontScale(scalePercentage);
  });
  
  bridge.registerHandler('jumpToPostWithID', function(postID) {
    window.location.hash = '';
    window.location.hash = '#' + postID;
  });
  
  bridge.registerHandler('markReadUpToPostWithID', function(postID) {
    var lastReadIndex = $('#' + postID).index();
    if (lastReadIndex === -1) return;
    $('post').each(function(i) {
      $(this).toggleClass('seen', i <= lastReadIndex);
    });
  });
  
  bridge.registerHandler('prependPosts', function(html) {
    var oldHeight = document.documentElement.scrollHeight;
    $('#posts').prepend(html);
    var newHeight = document.documentElement.scrollHeight;
    window.scrollBy(0, newHeight - oldHeight);
  });

  bridge.registerHandler('postHTMLAtIndex', function(data) {
    var html = highlightMentions($(data['HTML']));
    $('post').eq(data['index']).replaceWith(html);
  });
  
  bridge.registerHandler('showAvatars', function(show) {
    showAvatars(show);
  });
  
  bridge.registerHandler('loadLinkifiedImages', function() {
    $('[data-awful-linkified-image]').each(function() { showLinkifiedImage(this); });
  });
  
  bridge.registerHandler('highlightMentionUsername', function(username) {
    var oldUsername = Awful._highlightMentionUsername;
    if (!username || oldUsername !== username) {
      $('span.mention').each(function() {
        this.parentNode.replaceChild(this.firstChild, this);
        this.parentNode.normalize();
      });
    }
    
    Awful._highlightMentionUsername = username
    if (username) {
      $('.postbody').each(highlightMentions);
    }
  });
  
  bridge.registerHandler('interestingElementsAtPoint', function(point, callback) {
    var items = interestingElementsAtPoint(point.x, point.y);
    callback(items);
  });
  
  bridge.registerHandler('endMessage', function(message) {
    $('#end').text(message || '');
  });
  
  $(function() {
    $('body').on('tap', 'header .avatar, header .nameanddate', function(event) {
      bridge.callHandler('didTapUserHeader', clickData(this));
    });
    
    $('body').on('tap', '.action-button', function(event) {
      bridge.callHandler('didTapActionButton', clickData(this));
    });
    
    function clickData(element) {
      return {
        rect: rectOfElement(element),
        postIndex: $(element).closest('post').index()
      };
    }
  });
});

$(function() {
  $('.postbody').each(function() { highlightMentions(this); });
});

// Action sheet popovers need to get this information synchronously, so these functions are meant to be called directly from Objective-C. They each return a CGRectFromString-formatted bounding rect.
function HeaderRectForPostAtIndex(postIndex, popover) {
  var post = $('post').eq(postIndex);
  if (popover) {
    // Want to point just to the avatar/username, but the <header> extends across the page.
    return rectOfElement(post.find('.avatar, .nameanddate'));
  } else {
    return rectOfElement(post.find('header'));
  }
}
function FooterRectForPostAtIndex(postIndex) {
  return rectOfElement($('post').eq(postIndex).find('footer'));
}
function ActionButtonRectForPostAtIndex(postIndex) {
  return rectOfElement($('post').eq(postIndex).find('.action-button'));
}

// Finds all occurrences of the logged-in user's name in post text and wrap each in a <span class="mention">.
function highlightMentions(post) {
  var username = Awful._highlightMentionUsername;
  if (!username) return;
  var regex = new RegExp("\\b" + regexEscape(username) + "\\b", "i");
  var posts = $(post);
  posts.each(function() { eachTextNode(this, replaceAll); });
  return posts;
  
  function regexEscape(s) {
    return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')
  }
  function eachTextNode(node, callback) {
    if (node.nodeType === Node.TEXT_NODE) callback(node)
    for (var i = 0, len = node.childNodes.length; i < len; i++) {
      eachTextNode(node.childNodes[i], callback)
    }
  }
  function replaceAll(node) {
    if ($(node.parentNode).filter('span.mention').length > 0) return
    var match = node.data.match(regex)
    if (match === null) return
    var nameNode = node.splitText(match.index)
    var rest = nameNode.splitText(username.length)
    var span = node.ownerDocument.createElement('span')
    span.className = 'mention'
    span.appendChild(nameNode.cloneNode(true))
    node.parentNode.replaceChild(span, nameNode)
    replaceAll(rest)
  }
}

/*
 * Hide offscreen images and load them as they come into view.
 * Complication 1: the server doesn't send the image dimensions, so
 *                we set them ourselves based on what they are
 *                once loaded.
 * Complication 2: we want to prevent offscreen images from loading
 *                 on first display, before any scrolling, and before
 *                 load the image's dimensions default to 0x0. If we
 *                 are about to show an image with width of 0, forget
 *                 our saved values and save them again when next hidden.
 */
(function () {
  function postImages() {
    /* we only hide post-content images that aren't smilies */
    return $('.postbody img').not('[src*=somethingawful]');
  }

  /* Use a (viewport/2)-sized buffer below to get a bit ahead of the scroll. */
  function isInViewport() {
    var rect = this.getBoundingClientRect();
    var viewportHeight = window.innerHeight;
    return rect.bottom > 0 && rect.top < viewportHeight * 1.5;
  }

  function showImage() {
    var img = $(this); /* why is this not already zepto-wrapped? */
    if (!img.attr("data-orig-src")) {
      /* hasn't been hidden */
      return;
    }
    img.attr("src", img.attr("data-orig-src"));
    if (img.attr("width") == 0) {
      /*
       * We've never loaded this image, so width was defaulted to 0 during 
       * the initial scan. Remove those attributes so we get natural sizing
       * and we'll capture them when next we hide them.
       */
       img.attr("width", null);
       img.attr("height", null);
     }

     // console.log("Showing: ", img.attr("src"));
   }

   function hideImage() {
    var img = $(this);
    var src = img.attr("src");
    if (src == "about:blank" || !src) {
      /* already hidden, happens when multiple events trip */
      return;
    }

    // console.log("Hiding: ", src);
    img.attr("data-orig-src", img.attr("src"));
    img.attr("height", img.height());
    img.attr("width", img.width());
    img.attr("src", "about:blank");
  }

  function handleScroll() {
    var visibleSet = postImages().filter(isInViewport);

    postImages().filter(isInViewport).each(showImage);
    postImages().not(isInViewport).each(hideImage);
  }


  $(function () {
    handleScroll();
  });

  /* The UIWebView scroll event model can bite me. */
  document.addEventListener("touchmove", handleScroll, false);
  document.addEventListener("scroll", handleScroll, false);
  document.addEventListener("gesturechange", handleScroll, false);
})();