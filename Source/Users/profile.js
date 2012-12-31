;(function(exports){

var Awful = exports.Awful = {}

Awful.render = function(profile){
  $('#profile').html($('#template').mustache(profile))
}

Awful.dark = function(dark){
  if (dark) $('body').addClass('dark')
  else $('body').removeClass('dark')
}
  
})(window)
