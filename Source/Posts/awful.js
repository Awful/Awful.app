;(function(){
var Awful = {}

Awful.posts = function(posts){
  $('#posts').empty()
  $.each(posts, function(i, post){
    $('#postTemplate').mustache(post).appendTo('#posts')
  })
}

window.Awful = Awful
})()
