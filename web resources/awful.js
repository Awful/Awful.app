function tappedBottom()
{
    Awful.send("nextPage");
}

function tappedOlderPosts()
{
    Awful.send("loadOlderPosts");
}

function tappedPost(postid, el)
{
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

function scrollToID(postid)
{   
    var obj = document.getElementById(postid);
    document.getElementById(postid).scrollIntoView();
}
