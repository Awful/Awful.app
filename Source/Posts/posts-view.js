// Assumes zepto.js is available.

;(function(){
var Awful = {}

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

window.Awful = Awful
})()

function startBridge(callback) {
  if (window.WebViewJavascriptBridge) {
    callback(WebViewJavascriptBridge);
  } else {
    document.addEventListener('WebViewJavascriptBridgeReady', function() {
      callback(WebViewJavascriptBridge);
    }, false);
  }
}

startBridge(function(bridge) {
  bridge.init();
  
  bridge.registerHandler('changeStylesheet', function(css) {
    $('#awful-inline-style').text(css);
  });
  
  bridge.registerHandler('fontScale', function(scalePercentage) {
    var style = $('#awful-font-scale-style');
    if (scalePercentage == 100) {
      style.text('');
    } else {
      style.text(".nameanddate, .postbody, footer { font-size: " + scalePercentage + "%; }");
    }
  });
  
  bridge.registerHandler('markReadUpToPostWithID', function(postID) {
    var lastReadIndex = $('#' + postID).index();
    if (lastReadIndex === -1) return;
    $('post').each(function(i) {
      $(this).toggleClass('seen', i <= lastReadIndex);
    });
  });
  
  bridge.registerHandler('prependPosts', function(html) {
    var oldHeight = document.documentElement.scrollHeight;
    $('#posts').prepend(posts);
    var newHeight = document.documentElement.scrollHeight;
    window.scrollBy(0, newHeight - oldHeight);
  });

  bridge.registerHandler('postHTMLAtIndex', function(data) {
    var html = Awful.highlightMentions($(data['HTML']));
    $('post').eq(data['index']).replaceWith(html);
  });
  
  bridge.registerHandler('showAvatars', function(show) {
    if (show) {
      $('header[data-awful-avatar]').each(function() {
        var header = $(this);
        var img = $('<img>', {
          src: header.data('awful-avatar'),
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
        img.closest('header').data('awful-avatar', img.attr('src'));
        img.remove();
        img.closest('post').addClass('no-avatar');
      });
    }
  });
  
  bridge.registerHandler('loadLinkifiedImages', function() {
    $('[data-awful-linkified-image]').each(function() { showLinkifiedImage(this); });
  });
  
  bridge.registerHandler('highlightMentionUsername', function(username) {
    var oldUsername = Awful._highlightMentionUsername;
    if (!username || oldUsername !== username) {
      $('span.mention').each(function() {
        this.parentNode.replaceChild(this.firstChild, this);
        this.parentNode.normalize();
      });
    }
    
    Awful._highlightMentionUsername = username
    if (username) {
      $('.postbody').each(Awful.highlightMentions);
    }
  });
  
  bridge.registerHandler('endMessage', function(message) {
    $('#end').text(message || '');
  });
});

$(function() {
  $('body').on('click', '.bbc-spoiler', function(event) {
    var target = $(event.target);
    var spoiler = target.closest('.bbc-spoiler');
    var isLink = target.closest('a, [data-awful-linkified-image]').length > 0;
    var isSpoiled = spoiler.hasClass('spoiled');
    if (!(isLink && isSpoiled)) {
      spoiler.toggleClass('spoiled');
    }
    if (isLink && !isSpoiled) {
      event.preventDefault();
    }
  });
  
  $('body').on('click', '[data-awful-linkified-image]', function(event) {
    var link = $(event.target);
    if (link.closest('.bbc-spoiler:not(.spoiled)').length > 0) {
      return;
    }
    showLinkifiedImage(link);
    
    // Don't follow links when showing linkified images.
    event.preventDefault();
  });
  
  $('.postbody').each(function() { Awful.highlightMentions(this); });
});

function showLinkifiedImage(link) {
  link = $(link);
  link.replaceWith($('<img>', { border: 0, alt: '', src: link.text() }));
}

function highlightMentions(post) {
  var username = Awful._highlightMentionUsername;
  if (!username) return;
  var regex = new RegExp("\\b" + regexEscape(username) + "\\b", "i");
  var posts = $(post);
  posts.each(function() { eachTextNode(this, replaceAll); });
  return posts;
  
  function regexEscape(s) {
    return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')
  }
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
