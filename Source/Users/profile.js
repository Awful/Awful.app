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
  
  bridge.registerHandler('darkMode', function(dark) {
    $('body').toggleClass('dark', dark);
  });

  $(function() {
    $('#contact').on('click', 'tr', function(event) {
      var row = $(this);
      var service = row.find('th').text();
      var address = row.find('td').text();
      function rectOfElement(element) {
        var rect = element.offset();
        var origin = [rect.left - window.pageXOffset, rect.top - window.pageYOffset];
        var size = [rect.width, rect.height];
        return "{{" + origin.join(',') + "},{" + size.join(',') + "}}";
      }
      var data = {
        service: service,
        address: address,
        rect: rectOfElement(row)
      };
      bridge.callHandler('contactInfo', data);
    });
  });
});
