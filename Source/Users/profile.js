// Assumes common.js is available.

startBridge(function(bridge) {
  bridge.init();
  
  bridge.registerHandler('darkMode', function(dark) {
    $('body').toggleClass('dark', dark);
  });

  $(function() {
	$('#headerBackground').css('height', $('#content > section > header').height());
    $('#contact').on('click', 'tr', function(event) {
      var row = $(this);
      var service = row.find('th').text();
      var address = row.find('td').text();
      var data = {
        service: service,
        address: address,
        rect: rectOfElement(row)
      };
      bridge.callHandler('contactInfo', data);
    });
  });
});
