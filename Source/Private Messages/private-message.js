$(function() {
  FastClick.attach(document.body);
});

function startBridge(callback) {
  if (window.WebViewJavascriptBridge) {
    callback(WebViewJavascriptBridge);
  } else {
    document.addEventListener('WebViewJavascriptBridgeReady', function() {
      callback(WebViewJavascriptBridge);
    }, false);
  }
}

startBridge(function(bridge) {
  bridge.init();

  $(function() {
    $('post').on('click', 'header', function(event) {
      bridge.callHandler('didTapUserHeader', HeaderRect());
    });

    bridge.registerHandler('interestingElementsAtPoint', function(point, callback) {
      var items = {};
      var elementAtPoint = $(document.elementFromPoint(point.x, point.y));
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

      callback(items);
    });
    
    bridge.registerHandler('loadLinkifiedImages', function() {
      $('[data-awful-linkified-image]').each(function() { showLinkifiedImage(this); });
    });
    
    bridge.registerHandler('showAvatars', function(show) {
      if (show) {
        $('header[data-awful-avatar]').each(function() {
          var header = $(this);
          var img = $('<img>', { src: header.data('awful-avatar'), alt: '', class: 'avatar' });
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
    });
    
    bridge.registerHandler('changeStylesheet', function(stylesheet) {
      $('#awful-inline-style').text(stylesheet);
    });
    
    bridge.registerHandler('fontScale', function(scalePercentage) {
      var style = $('#awful-font-scale-style');
      if (scalePercentage == 100) {
        style.text('');
      } else {
        style.text(".postbody { font-size: " + scalePercentage + "%; }");
      }
    });
  });
});

function HeaderRect() {
  return rectOfElement($('header'));
}

function showLinkifiedImage(link) {
  link = $(link);
  link.replaceWith($('<img>', { border: 0, alt: '', src: link.text() }));
}

$(function() {
  $('body').on('click', '[data-awful-linkified-image]', function(event) {
    var link = $(event.target);
    if (link.closest('.bbc-spoiler:not(.spoiled)').length > 0) {
      return;
    }
    showLinkifiedImage(link);
    
    // Don't follow links when showing linkified images.
    event.preventDefault();
  });
});
