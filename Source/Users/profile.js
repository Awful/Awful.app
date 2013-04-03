;(function(exports){

var Awful = exports.Awful = {}

Awful.render = function(profile){
  $('#profile').html($('#template').mustache(profile))
}

Awful.dark = function(dark){
  $('body').toggleClass('dark', dark)
}

Awful.invoke = function(selector /*, varargs */){
  var stem = "x-objc:///" + selector + "/"
  var args = Array.prototype.slice.call(arguments, 1)
  window.location.href = stem + encodeURIComponent(JSON.stringify(args))
}

$(function(){
  $('#profile').on('tap', '#contact', function(e){
    var row = $(e.target).closest('tr')
    if (row.length == 0) return
    var rect = row.offset()
    rect.left -= window.pageXOffset
    rect.top -= window.pageYOffset
    Awful.invoke("showActionsForServiceAtIndex:fromRectDictionary:", row.index(), rect)
  })
})

})(window)
