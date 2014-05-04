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
    $('#contact').on('click', 'tr', function(event) {
      var row = $(this);
      var service = row.find('th').text();
      var address = row.find('td').text();
      var rect = row.offset();
      rect.left -= window.pageXOffset;
      rect.top -= window.pageYOffset;
      var data = {
        service: service,
        address: address,
        rect: rect
      };
      bridge.callHandler('contactInfo', data);
    });
  });
});
