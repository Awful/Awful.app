;(function(){
var Awful = {}
Awful.leftoverPosts = []

Awful.posts = function(posts){
  var firstUnseen = 0
  $.each(posts, function(i, post){
    if (!post.beenSeen) {
      firstUnseen = i
      return false
    }
  })
  
  Awful.leftoverPosts = posts.slice(0, firstUnseen)
  $('#posts').empty()
  
  $.each(posts.slice(firstUnseen), function(i, post){
    render(post).appendTo('#posts')
  })
  return Awful.leftoverPosts.length
}

Awful.invoke = function(selector, varargs){
  var stem = "x-objc:///" + selector + "/"
  var args = Array.prototype.slice.call(arguments, 1)
  window.location.href = stem + encodeURIComponent(JSON.stringify(args))
}

Awful.stylesheetURL = function(url){
  $('link').attr('href', url)
}

Awful.dark = function(dark){
  if (dark) $('body').addClass('dark')
  else $('body').removeClass('dark')
}

Awful.showAllPosts = function(){
  var firstAlreadyShown = $('#posts > article').first()
  var oldTop = firstAlreadyShown.offset().top
  $.each(Awful.leftoverPosts, function(i, post){
    render(post).insertBefore(firstAlreadyShown)
  })
  return firstAlreadyShown.offset().top - oldTop
}

Awful.ad = function(ad){
  $('#ad').html(ad)
}

var baseURL = "http://forums.somethingawful.com/"

function render(post) {
  rendered = $('#postTemplate').mustache(post)
  rendered.find('a:not([href *= "://"])').each(function(){
    var a = $(this)
    a.attr('href', baseURL + a.attr('href'))
  })
  rendered.find('img:not([src *= "://"])').each(function(){
    var img = $(this)
    img.attr('src', baseURL + img.attr('src'))
  })
  return rendered
}

window.Awful = Awful
})()


;(function(){

$(function(){
  $('body').addClass($.os.ipad ? 'ipad' : 'iphone')
  
  $('#posts').on('click', 'article > header > button', showPostActions)
  
  $('#posts').on('longTap', 'article > section > img', previewImage)
})

function showPostActions(e) {
  var button = $(e.target)
  var post = button.closest('article')
  var indexOfPost = post.index() + Awful.leftoverPosts.length
  var rect = button.offset()
  rect.left -= window.pageXOffset
  rect.top -= window.pageYOffset
  Awful.invoke("showActionsForPostAtIndex:fromRectDictionary:", indexOfPost, rect)
}

function previewImage(e) {
  var img = $(e.target)
  Awful.invoke("previewImageAtURLString:", img.attr('src'))
}

})()
