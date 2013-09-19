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
  } else if (i >= $('#posts > article').length) {
    render(post).appendTo('#posts')
  } else {
    $('#posts > article').eq(i).before(render(post))
  }
}

Awful.deletePost = function(post, i){
  $('#posts > article').eq(i).remove()
}

Awful.post = function(i, post){
  $('#posts > article').eq(i).replaceWith(render(post))
}

Awful.stylesheetURL = function(url){
  if ($('link').length) {
    $('link').attr('href', url)
  } else {
    $('head').append($('<link>', { rel: 'stylesheet', href: url }))
    $('#awful-inline-style').remove()
  }
}

Awful.dark = function(dark){
  $('body').toggleClass('dark', dark)
}

Awful.ad = function(ad){
  $('#ad').html(ad)
}

Awful.endMessage = function(end){
  $('#end').text(nullOrUndefined(end) ? '' : end)
}

Awful.highlightQuoteUsername = function(username){
  Awful._highlightQuoteUsername = username
  if (nullOrUndefined(username)) {
    $('.bbc-block.mention').removeClass('mention')
  } else {
    $('.postbody').each(function(){ highlightQuotes(this) })
  }
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

Awful.showAvatars = function(on){
  Awful._showAvatars = !!on
  if (on) {
    $('#posts > article > header[data-avatar]').each(function(){
      $('<img>', { src: $(this).data('avatar'), alt: '', class: 'avatar' }).prependTo($(this))
      $(this).data('avatar', null)
      $(this).closest('article').removeClass('no-avatar')
    })
  } else {
    $('#posts > article > header > img').each(function(){
      hideAvatar($(this).closest('article'))
    })
  }
}

Awful.showImages = function(on){
  Awful._showImages = !!on
  if (on) {
    $('#posts > article > section a[data-awful="image"]').each(function(){
      $(this).replaceWith($('<img>', { src: $(this).text(), border: '0' }))
    })
  } else {
    $('#posts > article').each(function(){
      hideImages(this)
    })
  }
}

Awful.postWithButtonForPoint = function(x, y){
  var button = $(document.elementFromPoint(x, y)).closest('button')
  if (button.length) {
    var post = button.closest('article')
    return JSON.stringify({ rect: rectOf(button), postIndex: post.index() })
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
  post = $(post)
  
  // Some links and images come with relative URLs, which break as we set our
  // relative URL to the app's resource directory. Let's fix those up.
  post.find('a:not([href *= ":"])').each(function(){
    var a = $(this)
    a.attr('href', prependBaseURL(a.attr('href')))
  })
  post.find('img:not([src *= ":"])').each(function(){
    var img = $(this)
    img.attr('src', prependBaseURL(img.attr('src')))
  })
  
  // We style spoilers ourselves.
  post.find('span.bbc-spoiler')
      .removeAttr('onmouseover')
      .removeAttr('onmouseout')
      .removeAttr('style')
  
  // Remove empty "editedby" paragraphs; they make for ugly spacing.
  post.find('.editedby').filter(function(){ return $(this).text().trim().length == 0 }).remove()
  
  if (!Awful._showAvatars) hideAvatar(post)
  if (!Awful._showImages) hideImages(post)
  highlightQuotes(post.find('.postbody'))
  highlightMentions(post.find('.postbody'))
  fixVimeoEmbeds(post)
  return post
}

function prependBaseURL(relativeURL) {
  return "http://forums.somethingawful.com" + (relativeURL.indexOf('/') !== 0 ? '/' : '') + relativeURL
}

function nullOrUndefined(arg) {
  return arg === null || arg === undefined
}

function highlightQuotes(post) {
  var username = Awful._highlightQuoteUsername
  if (nullOrUndefined(username)) return
  $(post).find('.bbc-block h4').each(function(){
    var text = $(this).text()
    if (text.indexOf(username) === 0 && text.indexOf("posted") !== -1) {
      $(this).closest('div.bbc-block').addClass('mention')
    }
  })
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

function fixVimeoEmbeds(post) {
  $(post).find('div.bbcode_video object param[value^="http://vimeo.com"]').each(function(){
    var videoID = $(this).attr('value').match(/clip_id=(\d+)/)
    if (videoID === null) return
    videoID = videoID[1]
    var object = $(this).closest('object')
    $(this).closest('div.bbcode_video').replaceWith($('<iframe/>', {
      src: "http://player.vimeo.com/video/" + videoID + "?byline=0&portrait=0",
      width: object.attr('width'),
      height: object.attr('height'),
      frameborder: 0,
      webkitAllowFullScreen: '',
      allowFullScreen: ''
    }))
  })
}

function hideAvatar(post) {
  var img = $(post).find('header > img')
  if (img.length === 0) return
  img.closest('header').data('avatar', img.attr('src'))
  img.remove()
  $(post).addClass('no-avatar')
}

function hideImages(post) {
  $(post).children('section').find('img')
         .not('img[src*="://fi.somethingawful.com/images/smilies"]')
         .not('img[src*="://fi.somethingawful.com/safs/smilies"]')
         .not('img[src*="://i.somethingawful.com/images/emot"]')
         .not('img[src*="://i.somethingawful.com/forumsystem/emoticons"]')
         .not('img[src*="://fi.somethingawful.com/forums/posticons"]')
         .not('img[src*="://forumimages.somethingawful.com/forums/posticons"]')
         .not('img[src*="://forumimages.somethingawful.com/images"]')
         .each(function(){
    $(this).replaceWith($('<a data-awful="image"/>').text($(this).attr('src')))
  })
}

Awful.profile = {
  render: function(profile){
    $('#profile').html(profile)
  },
  
  serviceFromPoint: function(x, y){
    var el = document.elementFromPoint(x, y)
    var tr = $(el).closest('tr')
    if (tr.closest('#contact').length) {
      var rect = tr.offset()
      rect.left -= window.pageXOffset
      rect.top -= window.pageYOffset
      return JSON.stringify({ rect: rect, serviceIndex: tr.index() })
    }
  }
}

window.Awful = Awful
})()


;(function(){

$(function(){
  $('body').addClass($.os.ipad ? 'ipad' : 'iphone')
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
