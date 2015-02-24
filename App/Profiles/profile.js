// Assumes common.js is available.

function darkMode(dark) {
  $('body').toggleClass('dark', dark);
}

$(function() {
  $('#headerBackground').css('height', $('#content > section > header').height());
  
  $('#contact').on('tap', 'tr', function(event) {
    var row = $(this);
    var service = row.find('th').text();
    if (service === "Private Message") {
      webkit.messageHandlers.sendPrivateMessage.postMessage(true);
    } else if (service === "Homepage") {
      webkit.messageHandlers.showHomepageActions.postMessage({
        URL: row.find('td').text(),
        rect: rectOfElement(row)
      });
    }
  });
});
