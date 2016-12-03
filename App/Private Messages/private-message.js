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
  });

  bridge.registerHandler('interestingElementsAtPoint', function(point, callback) {
    var items = interestingElementsAtPoint(point.x, point.y);
    callback(items);
  });
  
  bridge.registerHandler('loadLinkifiedImages', function() {
    $('[data-awful-linkified-image]').each(function() { showLinkifiedImage(this); });
  });
            
  bridge.registerHandler('embedTweets', function() {
      window.twttr.events.bind(
          'loaded',
          function (event) {
              bridge.callHandler('didFinishLoadingTweets', null);
          }
          );
      var URLs = $('a').toArray();
      window.Awful.tweets = [];
      
      var e;
      for (var i = 0; i < URLs.length; i++) {
          e = parseTweetURL(URLs[i]);
          if (e != null) {
              window.Awful.tweets.push(URLs[i]);
          }
      }
      
      for (var i = 0; i < window.Awful.tweets.length; i++) {
          embedTweet(window.Awful.tweets[i]);
      }
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
    
    bridge.registerHandler('jumpToFractionalOffset', function(offset) {
        window.scroll(0, document.body.scrollHeight * offset);
    });
});

// Action sheet popovers need to synchronously get the bounding rect of the header. The bridge can't help us, so here's a function meant to be called directly from Objective-C.
function HeaderRect() {
  
  // Want to point to avatar + username, whereas the header goes the whole width of the view.
  return rectOfElement($('.avatar, .nameanddate'));
}
