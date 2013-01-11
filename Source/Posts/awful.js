;(function(){
var Awful = {}
var spinner

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

Awful.invoke = function(selector, varargs){
  var stem = "x-objc:///" + selector + "/"
  var args = Array.prototype.slice.call(arguments, 1)
  window.location.href = stem + encodeURIComponent(JSON.stringify(args))
}

Awful.invokeOnView = function(selector, varargs){
  var stem = "x-objc-postsview:///" + selector + "/"
  var args = Array.prototype.slice.call(arguments, 1)
  window.location.href = stem + encodeURIComponent(JSON.stringify(args))
}

Awful.stylesheetURL = function(url){
  if ($('link').length) {
    $('link').attr('href', url)
    return
  }
  $('head').append($('<link>', { rel: 'stylesheet', href: url }))
  var img = $('<img>', { src: url })[0]
  img.onerror = function(){
    Awful.firstStylesheetDidLoad()
  }
}

Awful.firstStylesheetDidLoad = function(){
  addSpinnerIfNecessary()
  Awful.invokeOnView('firstStylesheetDidLoad')
}

Awful.dark = function(dark){
  if (dark) $('body').addClass('dark')
  else $('body').removeClass('dark')
  if (spinner) {
    spinner.stop()
    spinner = null
    addSpinnerIfNecessary()
  }
}

Awful.ad = function(ad){
  $('#ad').html(ad)
}

Awful.loading = function(loading){
  if (nullOrUndefined(loading)) {
    $('#loading').hide().siblings('div').show()
    if (spinner) {
      spinner.stop()
      spinner = null
    }
  } else {
    $('#loading').show().siblings('div').hide()
    addSpinnerIfNecessary()
    $('#loading p').text(loading)
  }
}

function addSpinnerIfNecessary() {
  var $bar = $('#loading .progress-bar')
  if ($bar.css('display') !== 'none') return
  spinner = new Spinner({ color: $bar.css('color'), width: 3 }).spin()
  $bar.parent().prepend(spinner.el)
}

Awful.endMessage = function(end){
  $('#end').text(nullOrUndefined(end) ? '' : end)
}

Awful.highlightQuoteUsername = function(username){
  Awful._highlightQuoteUsername = username
  if (nullOrUndefined(username)) {
    $('div.bbc-block.highlight').removeClass('highlight')
  } else {
    $('#posts > article > section').each(function(){
      highlightQuotes(this)
    })
  }
}

Awful.highlightMentionUsername = function(username){
  Awful._highlightMentionUsername = username
  if (nullOrUndefined(username)) {
    $('#posts > article > section span.highlight').each(function(){
      this.parentNode.replaceChild(this.firstChild, this)
      this.parentNode.normalize()
    })
  } else {
    $('#posts > article > section').each(function(){ highlightMentions(this) })
  }
}

Awful.showAvatars = function(on){
  Awful._showAvatars = !!on
  if (on) {
    $('#posts > article > header[data-avatar]').each(function(){
      $('<img>', { src: $(this).data('avatar'), alt: '' }).insertBefore($(this).children('button'))
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

function render(post) {
  rendered = $('#postTemplate').mustache(post)
  // Some links and images come with relative URLs, which break as we set our
  // relative URL to the app's resource directory. Let's fix those up.
  rendered.find('a:not([href *= ":"])').each(function(){
    var a = $(this)
    a.attr('href', prependBaseURL(a.attr('href')))
  })
  rendered.find('img:not([src *= ":"])').each(function(){
    var img = $(this)
    img.attr('src', prependBaseURL(img.attr('src')))
  })
  // We style spoilers ourselves.
  rendered.find('span.bbc-spoiler')
          .removeAttr('onmouseover')
          .removeAttr('onmouseout')
          .removeAttr('style')
  if (!Awful._showAvatars) hideAvatar(rendered)
  if (!Awful._showImages) hideImages(rendered)
  highlightQuotes(rendered)
  highlightMentions(rendered)
  return rendered
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
  $(post).find('div.bbc-block a.quote_link').each(function(){
    if ($(this).text().indexOf(username) === 0) {
      $(this).closest('div.bbc-block').addClass('highlight')
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
    if ($(node.parentNode).filter('span.highlight').length > 0) return
    var match = node.data.match(regex)
    if (match === null) return
    var nameNode = node.splitText(match.index)
    var rest = nameNode.splitText(username.length)
    var span = node.ownerDocument.createElement('span')
    span.className = 'highlight'
    span.appendChild(nameNode.cloneNode(true))
    node.parentNode.replaceChild(span, nameNode)
    replaceAll(rest)
  }
}

function regexEscape(s) {
  return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')
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

window.Awful = Awful
})()


;(function(){

$(function(){
  $('body').addClass($.os.ipad ? 'ipad' : 'iphone')
  
  $('#posts').on('tap', 'article > header > button', showPostActions)
  
  $('#posts').on('longTap', 'article > header', showProfile)
  
  $('#posts').on('longTap', 'article > section img', previewImage)
  
  $('#posts').on('click', 'a[data-awful="image"]', showLinkedImage)
  
  $('#posts').on('click', '.bbc-spoiler', toggleSpoiled)
  
  $('#posts').on('click', '.bbc-spoiler a', cancelUnspoiledLinks)
  
  $('#posts').on('longTap', 'article > section a', showLinkMenu)
})

function showPostActions(e) {
  var button = $(e.target)
  var post = button.closest('article')
  var rect = button.offset()
  rect.left -= window.pageXOffset
  rect.top -= window.pageYOffset
  Awful.invoke("showActionsForPostAtIndex:fromRectDictionary:", post.index(), rect)
}

function showProfile(e) {
  var target = $(e.target)
  if (target.is('button')) return true
  var header = target.is('header') ? target : target.closest('header')
  var rect = header.offset()
  rect.left -= window.pageXOffset
  rect.top -= window.pageYOffset
  var post = header.closest('article')
  Awful.invoke("showProfileForPostAtIndex:fromRectDictionary:", post.index(), rect)
}

function previewImage(e) {
  var src = $(e.target).attr('src')
  // Need to encode the URL to pass it through to Objective-C land. It may already be encoded, so we can't blindly encode it. It may also require encoding (a common one is spaces in image URLs for some reason) so we need to encode it at some point.
  var skip = src.indexOf('://') != -1 ? 1 : 0
  var decodedParts = $.map(src.split('/'), function(part, i){
    return i < skip ? part : decodeURIComponent(part)
  })
  var url = encodeURI(decodedParts.join('/'))
  Awful.invoke("previewImageAtURLString:", url)
}

function showLinkedImage(e) {
  var link = $(e.target)
  link.replaceWith($('<img border=0>').attr('src', link.text()))
  e.preventDefault()
}

function toggleSpoiled(e) {
  $(e.target).toggleClass('spoiled')
}

function cancelUnspoiledLinks(e) {
  var link = $(e.target)
  var spoiler = link.closest('.bbc-spoiler')
  if (!spoiler.hasClass('spoiled')) {
    spoiler.addClass('spoiled')
    e.preventDefault()
  }
}

function showLinkMenu(e) {
  var link = $(e.target).closest('a')
  var rect = link.offset()
  rect.left -= window.pageXOffset
  rect.top -= window.pageYOffset
  Awful.invoke("showMenuForLinkWithURLString:fromRectDictionary:", link.attr('href'), rect)
  e.preventDefault()
}

})()
