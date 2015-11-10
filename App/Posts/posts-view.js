// Assumes common.js is available.

// Storage for a couple globals.
if (!window.Awful) { window.Awful = {}; }

startBridge(function(bridge) {
  bridge.init();
  
  bridge.registerHandler('changeStylesheet', function(css) {
    $('#awful-inline-style').text(css);
  });
  
  bridge.registerHandler('changeExternalStylesheet', function(css) {
    $('#awful-external-style').text(css);
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
    $('.imgurGif').load(function(event){
        $(event.target).parent().addClass('overlay');
    }).each(function() {
        if (this.complete) {
            $(this).load();
        }
    });
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
    var oldUsername = window.Awful._highlightMentionUsername;
    if (!username || oldUsername !== username) {
      $('span.mention').each(function() {
        this.parentNode.replaceChild(this.firstChild, this);
        this.parentNode.normalize();
      });
    }
    
    window.Awful._highlightMentionUsername = username
    if (username) {
      $('.postbody').each(highlightMentions);
    }
  });
  
  bridge.registerHandler('interestingElementsAtPoint', function(point, callback) {
    var items = interestingElementsAtPoint(point.x, point.y);
    callback(items);
  });
  
  $(function() {
    $('body').on('tap', 'header .avatar, header .nameanddate', function(event) {
      bridge.callHandler('didTapUserHeader', clickData(this));
    });
    
    $('body').on('tap', '.action-button', function(event) {
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

$(function() {
  if ($('body.forum-26').length !== 0) {
    var timer = 0;
    var fetchFlag = function() {
      clearInterval(timer);
      
      $.getJSON("/flag.php?forumid=26", function(data) {
        var img = $("<img>", {
          title: "this flag proudly brought to you by " + data.username + " on " + data.created,
          src: "http://fi.somethingawful.com/flags" + data.path + "?by=" + encodeURIComponent(data.username),
        });
        var div = $('#fyad-flag');
        if (div.length > 0) {
          div.empty();
          div.append(img);
        } else {
          $(img).insertBefore('#posts').wrap('<div id="fyad-flag">');
        }
        
        timer = setTimeout(fetchFlag, 60000);
      });
    };
    
    fetchFlag();
  }
});

// Action sheet popovers need to get this information synchronously, so these functions are meant to be called directly from Objective-C. They each return a CGRectFromString-formatted bounding rect.
function HeaderRectForPostAtIndex(postIndex) {
  var post = $('post').eq(postIndex);
  
  // Want to point just to the avatar/username, but the <header> extends across the page.
  return rectOfElement(post.find('.avatar, .nameanddate'));
}
function FooterRectForPostAtIndex(postIndex) {
  return rectOfElement($('post').eq(postIndex).find('footer'));
}
function ActionButtonRectForPostAtIndex(postIndex) {
  return rectOfElement($('post').eq(postIndex).find('.action-button'));
}

// Finds all occurrences of the logged-in user's name in post text and wrap each in a <span class="mention">.
function highlightMentions(post) {
  var username = window.Awful._highlightMentionUsername;
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
