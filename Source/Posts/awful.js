;(function(){
var Awful = {}

Awful.posts = function(posts){
  $('#posts').empty()
  $.each(posts, function(i, post){
    $('#postTemplate').mustache(post).appendTo('#posts')
  })
}

Awful.invoke = function(selector, varargs){
  var url = "x-objc:///" + selector
  var args = Array.prototype.slice.call(arguments, 1)
  if (args.length > 0)
    url += "/" + encodeURIComponent(JSON.stringify(args))
  window.location.href = url
}

Awful.setStylesheetURL = function(url){
  $('link').attr('href', url)
}

Awful.setDark = function(dark){
  if (dark) $('body').addClass('dark')
  else $('body').removeClass('dark')
}

window.Awful = Awful
})()


$(function(){
  $('body').addClass($.os.ipad ? 'ipad' : 'iphone')
  
  $('#posts').on('click', 'button', showPostActions)
  
  $('#posts').on('longTap', 'article > section > img', previewImage)
})

function showPostActions(e) {
  var button = $(e.target)
  var post = button.closest('article')
  var rect = button.offset()
  rect.left -= window.pageXOffset
  rect.top -= window.pageYOffset
  Awful.invoke("showActionsForPostAtIndex:fromRectDictionary:", post.index(), rect)
}

function previewImage(e) {
  var img = $(e.target)
  Awful.invoke("previewImageAtURLString:", img.attr('src'))
}
