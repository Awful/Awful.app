function tappedBottom() {
    Awful.send("nextPage");
}

function tappedOlderPosts() {
    Awful.send("loadOlderPosts");
}

function tappedPost(postid, el) {
    var infoDict = { postID: postid };
    if (el) {
        var offset = $(el).offset();
        var scroll = { left: $(window).scrollLeft(), top: $(window).scrollTop() };
        var position = { left: offset.left - scroll.left, top: offset.top - scroll.top };
        var origin = "{" + position.left + "," + position.top + "}";
        var size = "{" + $(el).width() + "," + $(el).height() + "}";
        infoDict.rect = "{" + origin + "," + size + "}";
    }
    Awful.send("postOptions", infoDict);
}

function scrollToID(postid) {
    var obj = document.getElementById(postid);
    document.getElementById(postid).scrollIntoView();
}
function scrollToBottom() {
    window.scrollTo(0, document.body.scrollHeight);
}

function addAvatarClass() {
    $('article').each(function(){
      var avatarSrc = $(this).find('.avatar').attr('src');
      if(avatarSrc == null) {
         $(this).addClass('noAvatar');
      }
    });
}

function imageURLAtPosition(x, y) {
    var img = $(document.elementFromPoint(x, y))
              .filter('img')
              .not('.postaction')
              .not('img[src*=http://i.somethingawful.com/forumsystem/emoticons/]')
              .not('img[src*=http://fi.somethingawful.com/images/smilies/]');
    return !!img[0] ? img[0].src : null;
}