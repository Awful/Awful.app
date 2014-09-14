/* JavaScript used from at least two different places. */

// Assumes Zepto is available.

// Starts the WebViewJavascriptBridge.
function startBridge(callback) {
  if (window.WebViewJavascriptBridge) {
    callback(WebViewJavascriptBridge);
  } else {
    document.addEventListener('WebViewJavascriptBridgeReady', function() {
      callback(WebViewJavascriptBridge);
    });
  }
}

$(function() {
  
  // Toggles spoilers on tap.
  $('body').on('tap', '.bbc-spoiler', function(event) {
    var target = $(event.target);
    var spoiler = target.closest('.bbc-spoiler');
    var nearestLink = target.closest('a, [data-awful-linkified-image]');
    var isLink = nearestLink.length > 0;
    var isSpoiled = spoiler.hasClass('spoiled');
    if (!(isLink && isSpoiled)) {
      spoiler.toggleClass('spoiled');
    }
    if (isLink && !isSpoiled) {
      event.stopImmediatePropagation();
      preventNextClickEvent();
    }
  });

  // Shows linkified images on tap.
  $('body').on('tap', '[data-awful-linkified-image]', function(event) {
    var link = $(event.target);
    if (link.closest('.bbc-spoiler:not(.spoiled)').length > 0) {
      return;
    }
    showLinkifiedImage(link);
    preventNextClickEvent();
  });
  
  // Utility function intended to siphon off a 300ms-delayed click event that will follow a handled tap event.
  var preventNextClickEventListener;
  var preventer = function preventNextClickEvent() {
    if (preventNextClickEventListener) return;
    preventNextClickEventListener = function(event) {
      event.preventDefault();
      event.stopPropagation();
      document.body.removeEventListener('click', preventNextClickEventListener, true);
      preventNextClickEventListener = null;
    };
    document.body.addEventListener('click', preventNextClickEventListener, true);
  }
  if (!Awful) Awful = {};
  Awful.preventNextClickEvent = preventer;
});

// Returns the CGRectFromString-formatted bounding rect of an element or the union of the bounding rects of elements, suitable for passing back to Objective-C.
function rectOfElement(elements) {
  elements = $(elements);
  var unionRect = elements.offset();
  elements.slice(1).each(function() {
    var rect = $(this).offset();
    if (rect.left < unionRect.left) {
      unionRect.width += (unionRect.left - rect.left);
      unionRect.left = rect.left;
    }
    if (rect.top < unionRect.top) {
      unionRect.height += (unionRect.top - rect.top);
      unionRect.top = rect.top;
    }
    var rightDelta = (rect.left + rect.width) - (unionRect.left + unionRect.width);
    if (rightDelta > 0) {
      unionRect.width += rightDelta;
    }
    var bottomDelta = (rect.top + rect.height) - (unionRect.top + unionRect.height);
    if (bottomDelta > 0) {
      unionRect.height += bottomDelta;
    }
  });
  var origin = [unionRect.left - window.pageXOffset, unionRect.top - window.pageYOffset].join(",");
  var size = [unionRect.width, unionRect.height].join(",");
  return "{{" + origin + "},{" + size + "}}";
}

// Reveals or hides avatars in each post header.
function showAvatars(show) {
  if (show) {
    $('header[data-awful-avatar]').each(function() {
      var header = $(this);
      var img = $('<img>', {
        src: header.data('awful-avatar'),
        alt: '',
        class: 'avatar'
      });
      img.prependTo(header);
      header.data('avatar', null);
      header.closest('post').removeClass('no-avatar');
    });
  } else {
    $('header img.avatar').each(function() {
      var img = $(this);
      img.closest('header').data('awful-avatar', img.attr('src'));
      img.remove();
      img.closest('post').addClass('no-avatar');
    });
  }
}

// Replaces a linkified image with the image it represents.
function showLinkifiedImage(link) {
  link = $(link);
  link.replaceWith($('<img>', { border: 0, alt: '', src: link.text() }));
}

// Updates (or removes if 100%) the font scale setting.
function fontScale(scalePercentage) {
  var style = $('#awful-font-scale-style');
  if (scalePercentage == 100) {
    style.text('');
  } else {
    style.text(".nameanddate, .postbody, footer { font-size: " + scalePercentage + "%; }");
  }
}

// Returns an object of elements that may warrant further interaction.
//
// The returned object may include keys for:
//   * spoiledImageURL: a string URL pointing to an image.
//   * spoiledLink: an object with keys:
//     * rect: the link element's bounding box.
//     * URL: a string URL the link is pointing to.
//   * spoiledVideo: an object with keys:
//     * rect: the video element's bounding box.
//     * URL: a string URL pointing to the video.
function interestingElementsAtPoint(x, y) {
  var items = {};
  var elementAtPoint = $(document.elementFromPoint(x, y));
  function isSpoiled(element) {
    var spoiler = element.closest('.bbc-spoiler');
    return spoiler.length == 0 || spoiler.hasClass('spoiled');
  }

  var img = elementAtPoint.closest('img');
  if (img.length && isSpoiled(img)) {
    items.spoiledImageURL = img.attr('src');
  }

  var a = elementAtPoint.closest('a');
  if (a.length && isSpoiled(a)) {
    items.spoiledLink = {
      rect: rectOfElement(a),
      URL: a.attr('href')
    };
  }
  
  var iframe = elementAtPoint.closest('iframe');
  if (iframe.length && isSpoiled(iframe)) {
    items.spoiledVideo = {
      rect: rectOfElement(iframe),
      URL: iframe.attr('src')
    };
  };
  
  return items;
}
