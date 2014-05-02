;(function(){
var Awful = {}

Awful.posts = function(posts){
  $('#posts').empty()
  $.each(posts, function(i, post){
    render(post).appendTo('#posts')
  })
}

Awful.insertPost = function(post, i){
  if (i === 0) {
    render(post).prependTo('#posts')
  } else if (i >= $('post').length) {
    render(post).appendTo('#posts')
  } else {
    $('post').eq(i).before(render(post))
  }
}

Awful.deletePost = function(post, i){
  $('post').eq(i).remove()
}

Awful.post = function(i, post){
  $('post').eq(i).replaceWith(render(post))
}

Awful.markReadUpToPostWithID = function(postID) {
  var lastReadIndex = $('#' + postID).index();
  if (lastReadIndex == -1) return;
  $('post').each(function(i) {
    $(this).toggleClass('seen', i <= lastReadIndex);
  });
};

Awful.stylesheet = function(style){
  $('#awful-inline-style').text(style)
}

Awful.ad = function(ad){
  $('#ad').html(ad)
}

Awful.endMessage = function(end){
  $('#end').text(nullOrUndefined(end) ? '' : end)
}

Awful.highlightMentionUsername = function(username){
  Awful._highlightMentionUsername = username
  if (nullOrUndefined(username)) {
    $('span.mention').each(function(){
      this.parentNode.replaceChild(this.firstChild, this)
      this.parentNode.normalize()
    })
  } else {
    $('.postbody').each(function(){ highlightMentions(this) })
  }
}

Awful.showAvatars = function(on) {
  if (on) {
    $('header[data-avatar]').each(function() {
      var header = $(this);
      var img = $('<img>', {
        src: header.data('avatar'),
        alt: '',
        class: 'avatar'
      });
      img.prependTo(header);
      header.data('avatar', null);
      header.closest('post').removeClass('no-avatar');
    });
  } else {
    $('header img.avatar').each(function() {
      var img = $(this);
      img.closest('header').data('avatar', img.attr('src'));
      img.remove();
      img.closest('post').addClass('no-avatar');
    });
  }
}

Awful.loadLinkifiedImages = function() {
  $('a[data-awful="image"]').each(function() {
    var link = $(this);
    link.replaceWith($('<img>', { src: link.text(), border: 0 }));
  });
};

Awful.postWithButtonForPoint = function(x, y){
  var button = $(document.elementFromPoint(x, y)).closest('button')
  if (button.length) {
    var post = button.closest('post')
    return JSON.stringify({ rect: rectOf(button), postIndex: post.index() })
  }
}
	
Awful.postWithUserNameForPoint = function(x, y){
	var usernameHeading = $(document.elementFromPoint(x, y)).closest('h1')
	if (usernameHeading.length) {
		var post = usernameHeading.closest('post')
		return JSON.stringify({ rect: rectOf(usernameHeading), postIndex: post.index() })
	}
}

Awful.headerForPostWithID = function(postID){
  var post = $('#' + postID)
  if (post.length) {
    return JSON.stringify(rectOf(post.find('header')))
  }
}

Awful.footerForPostWithID = function(postID){
  var post = $('#' + postID)
  if (post.length) {
    return JSON.stringify(rectOf(post.find('footer')))
  }
}

Awful.actionButtonForPostWithID = function(postID){
  var post = $('#' + postID)
  if (post.length) {
    return JSON.stringify(rectOf(post.find('footer button')))
  }
}

function rectOf(el) {
  var rect = el.offset()
  rect.left -= window.pageXOffset
  rect.top -= window.pageYOffset
  return rect
}

Awful.spoiledImageInPostForPoint = function(x, y){
  var img = $(document.elementFromPoint(x, y)).closest('img')
  if (img.length) {
    var spoiler = img.closest('.bbc-spoiler')
    if (spoiler.length == 0 || spoiler.hasClass('spoiled')) {
      return JSON.stringify({ url: img.attr('src') })
    }
  }
}

Awful.spoiledLinkInPostForPoint = function(x, y){
  var a = $(document.elementFromPoint(x, y)).closest('a')
  if (a.length) {
    var spoiler = a.closest('.bbc-spoiler')
    if (spoiler.length == 0 || spoiler.hasClass('spoiled')) {
      return JSON.stringify({ rect: rectOf(a), url: a.attr('href') })
    }
  }
}

Awful.spoiledVideoInPostForPoint = function(x, y){
  var iframe = $(document.elementFromPoint(x, y)).closest('iframe')
  if (iframe.length) {
    var spoiler = iframe.closest('.bbc-spoiler')
    if (spoiler.length == 0 || spoiler.hasClass('spoiled')) {
      return JSON.stringify({ rect: rectOf(iframe), url: iframe.attr('src') })
    }
  }
}

function render(post) {
  post = $(post);
  highlightMentions(post.find('.postbody'));
  return post;
}

function nullOrUndefined(arg) {
  return arg === null || arg === undefined
}

function highlightMentions(post) {
  var username = Awful._highlightMentionUsername
  if (nullOrUndefined(username)) return
  var regex = new RegExp("\\b" + regexEscape(username) + "\\b", "i")
  eachTextNode($(post)[0], replaceAll)
  
  function eachTextNode(node, callback) {
    if (node.nodeType === Node.TEXT_NODE) callback(node)
    for (var i = 0, len = node.childNodes.length; i < len; i++) {
      eachTextNode(node.childNodes[i], callback)
    }
  }
  function replaceAll(node) {
    if ($(node.parentNode).filter('span.mention').length > 0) return
    var match = node.data.match(regex)
    if (match === null) return
    var nameNode = node.splitText(match.index)
    var rest = nameNode.splitText(username.length)
    var span = node.ownerDocument.createElement('span')
    span.className = 'mention'
    span.appendChild(nameNode.cloneNode(true))
    node.parentNode.replaceChild(span, nameNode)
    replaceAll(rest)
  }
}

function regexEscape(s) {
  return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')
}

window.Awful = Awful
})()


;(function(){

$(function(){
  $('#posts').on('click', 'a[data-awful="image"]', showLinkedImage)
  $('#posts').on('click', '.bbc-spoiler', toggleSpoiled)
})

function showLinkedImage(e) {
  var link = $(e.target)
  link.replaceWith($('<img border=0>').attr('src', link.text()))
  e.preventDefault()
}

function toggleSpoiled(e) {
  var target = $(e.target)
  var spoiler = target.closest('.bbc-spoiler')
  if (!spoiler.hasClass('spoiled') && target.filter('a').length) {
    e.preventDefault()
  }
  spoiler.toggleClass('spoiled')
}

})()
