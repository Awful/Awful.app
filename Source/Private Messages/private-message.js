// Assumes common.js is available.

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
      var items = interestingItemsAtPoint(point.x, point.y);
      callback(items);
    });
    
    bridge.registerHandler('loadLinkifiedImages', function() {
      $('[data-awful-linkified-image]').each(function() { showLinkifiedImage(this); });
    });
    
    bridge.registerHandler('showAvatars', function(show) {
      showAvatars(show);
    });
    
    bridge.registerHandler('changeStylesheet', function(stylesheet) {
      $('#awful-inline-style').text(stylesheet);
    });
    
    bridge.registerHandler('fontScale', function(scalePercentage) {
      fontScale(scalePercentage);
    });
  });
});

function HeaderRect() {
  return rectOfElement($('header'));
}
