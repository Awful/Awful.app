;(function(){
var Awful = {}
var previouslySeenPostsToShow = 0
var leftoverPosts = []

Awful.posts = function(posts){
  var firstUnseen = 0
  $.each(posts, function(i, post){
    if (!post.beenSeen) {
      firstUnseen = i
      return false
    }
  })
  
  var startAt = Math.max(firstUnseen - previouslySeenPostsToShow, 0)
  leftoverPosts = posts.slice(0, startAt)
  $('#posts').empty()
  
  $.each(posts.slice(startAt), function(i, post){
    render(post).appendTo('#posts')
  })
  return leftoverPosts.length
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

Awful.previouslySeenPostsToShow = function(previouslySeen){
  previouslySeenPostsToShow = previouslySeen
}

Awful.showAllPosts = function(){
  var firstAlreadyShown = $('#posts > article').first()
  var oldTop = firstAlreadyShown.offset().top
  $.each(leftoverPosts, function(i, post){
    render(post).insertBefore(firstAlreadyShown)
  })
  return firstAlreadyShown.offset().top - oldTop
}

function render(post) {
  return $('#postTemplate').mustache(post)
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
  var rect = button.offset()
  rect.left -= window.pageXOffset
  rect.top -= window.pageYOffset
  Awful.invoke("showActionsForPostAtIndex:fromRectDictionary:", post.index(), rect)
}

function previewImage(e) {
  var img = $(e.target)
  Awful.invoke("previewImageAtURLString:", img.attr('src'))
}

})()
