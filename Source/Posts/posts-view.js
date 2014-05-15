// Assumes common.js is available.

// Storage for a couple globals.
window.Awful = {};

startBridge(function(bridge) {
  bridge.init();
  
  bridge.registerHandler('changeStylesheet', function(css) {
    $('#awful-inline-style').text(css);
  });
  
  bridge.registerHandler('fontScale', function(scalePercentage) {
    fontScale(scalePercentage);
  });
  
  bridge.registerHandler('jumpToPostWithID', function(postID) {
    window.location.hash = '';
    window.location.hash = '#' + postID;
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
    $('#posts').prepend(html);
    var newHeight = document.documentElement.scrollHeight;
    window.scrollBy(0, newHeight - oldHeight);
  });

  bridge.registerHandler('postHTMLAtIndex', function(data) {
    var html = highlightMentions($(data['HTML']));
    $('post').eq(data['index']).replaceWith(html);
  });
  
  bridge.registerHandler('showAvatars', function(show) {
    showAvatars(show);
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
      $('.postbody').each(highlightMentions);
    }
  });
  
  bridge.registerHandler('interestingElementsAtPoint', function(point, callback) {
    var items = interestingElementsAtPoint(point.x, point.y);
    callback(items);
  });
  
  bridge.registerHandler('endMessage', function(message) {
    $('#end').text(message || '');
  });
  
  $(function() {
    $('body').on('click', 'header .avatar, header .nameanddate', function(event) {
      bridge.callHandler('didTapUserHeader', clickData(this));
    });
    
    $('body').on('click', '.action-button', function(event) {
      bridge.callHandler('didTapActionButton', clickData(this));
    });
    
    function clickData(element) {
      return {
        rect: rectOfElement(element),
        postIndex: $(element).closest('post').index()
      };
    }
  });
});

$(function() {
  $('.postbody').each(function() { highlightMentions(this); });
});

// Action sheet popovers need to get this information synchronously, so these functions are meant to be called directly from Objective-C. They each return a CGRectFromString-formatted bounding rect.
function HeaderRectForPostAtIndex(postIndex, popover) {
  var post = $('post').eq(postIndex);
  if (popover) {
    // Want to point just to the avatar/username, but the <header> extends across the page.
    return rectOfElement(post.find('.avatar, .nameanddate'));
  } else {
    return rectOfElement(post.find('header'));
  }
}
function FooterRectForPostAtIndex(postIndex) {
  return rectOfElement($('post').eq(postIndex).find('footer'));
}
function ActionButtonRectForPostAtIndex(postIndex) {
  return rectOfElement($('post').eq(postIndex).find('.action-button'));
}

// Finds all occurrences of the logged-in user's name in post text and wrap each in a <span class="mention">.
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
