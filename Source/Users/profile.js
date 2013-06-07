;(function(exports){

var Awful = exports.Awful = {}

Awful.render = function(profile){
  $('#profile').html(profile)
}

Awful.dark = function(dark){
  $('body').toggleClass('dark', dark)
}

Awful.serviceFromPoint = function(x, y){
  var el = document.elementFromPoint(x, y)
  var tr = $(el).closest('tr')
  if (tr.closest('#contact').length) {
    var rect = tr.offset()
    rect.left -= window.pageXOffset
    rect.top -= window.pageYOffset
    return JSON.stringify({ rect: rect, serviceIndex: tr.index() })
  }
}

})(window)
