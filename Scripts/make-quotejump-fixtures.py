#!/usr/bin/env python3
"""
Generates the `quotejump` fixture thread: a synthetic three-page Something Awful thread whose posts quote one another at strategic points, so the quote-jump test harness (App/Tests/QuoteJump) can exercise every "tap a quote, land on the quoted post" scenario against real `showthread.php` markup.

    python3 Scripts/make-quotejump-fixtures.py

writes, into AwfulCore/Tests/AwfulCoreTests/Fixtures/:

    quotejump-p1.html          page 1, posts 1-40, all seen
    quotejump-p2.html          page 2, posts 41-80, seen through post 59
    quotejump-p3.html          page 3, posts 81-120, none seen (the reader has read through 59)
    quotejump-p3-seen109.html  page 3 as it looks once the reader has read through post 109
    quotejump-p3-seen119.html  page 3 as it looks once the reader has read through post 119, as after posting the last reply

The thread is 9000001 in forum 1. Post IDs are 900000000 + page * 100 + index on page, so post 50 (page 2, 10th post) is 900000210; `post_id()` below is the single source of truth and QuoteJumpFixture.swift in the tests mirrors it.

Image URLs are emitted as `{{IMAGE_BASE}}/img/<name>.png?delay=<ms>&h=<px>`; the harness substitutes its local image server's origin before serving a page, and the server honours `delay` and `h`, so a scenario controls when media above a target finishes loading and by how much it grows.

The markup is pared down from AwfulCore/Tests/AwfulCoreTests/Fixtures/showthread.html to what PostsPageScrapeResult, PostScrapeResult and AuthorSidebarScrapeResult read: body data-forum/data-thread, div.pages with a select of pages, div.breadcrumbs with the thread link, div.threadbar with postbuttons, and table.post rows with td.userinfo, td.postbody, td.postdate and ul.profilelinks. Keep the output ASCII so it reads the same as Windows-1252 or UTF-8.

The strategic posts (numbers are index in thread):

    5    page 1   plain                      cross-page target on an earlier page
    20   page 1   three tall slow images     media above a cross-page target
    30   page 1   plain                      cross-page target with media above it
    42   page 2   plain, seen                same-page target behind "Previous Posts", nothing slow above it
    45-47 page 2  one tall slow image each   media above the hidden target 50 once Previous Posts are shown
    50   page 2   plain, seen                same-page target behind "Previous Posts" with media above it
    55   page 2   tweet link                 something for the tweet-loaded re-jump to fire on
    60   page 2   quotes 42, 50, 70, 76, 30, 5, 95, 118 and the deleted post 777777; the first unseen post, so the page opens here
    61   page 2   post link inside a closed spoiler
    70   page 2   plain                      same-page target below the viewport, nothing slow between
    72-74 page 2  one tall slow image each   media between the tapping post and the target 76
    76   page 2   plain                      same-page target below the viewport with media between
    95   page 3   plain                      cross-page target in the read region of the last page (seen109 variant)
    110  page 3   plain                      first unseen post in the seen109 variant
    115  page 3   two tall slow images       media above a cross-page target among unread posts
    118  page 3   plain                      cross-page target among unread posts
    120  page 3   filler                     the last post, short, and the first unseen post in the seen119 variant
"""

import argparse
import os
import sys
from urllib.parse import quote as url_quote

THREAD_ID = 9000001
FORUM_ID = 1
THREAD_TITLE = "Quote Jump Fixture Thread"
POSTS_PER_PAGE = 40
PAGE_COUNT = 3
DELETED_POST_ID = 777777

# Invented posters; none of these are real Forums accounts.
AUTHORS = [
    ("Quotey McQuoteface", 9000101, "Jan 2, 2026"),
    ("Scrolls Royce", 9000102, "Feb 3, 2026"),
    ("Page Turner", 9000103, "Mar 4, 2026"),
    ("Anchor Management", 9000104, "Apr 5, 2026"),
    ("Lazy Loader", 9000105, "May 6, 2026"),
]

FILLER = [
    "Hey, now, there's a lot of room for debate on this one. Like, a lot. Which is kind of sad, the more I think about it.",
    "I keep rereading the previous page and I'm still not sure anyone has actually answered the question.",
    "This is one of those threads where every third post is just someone quoting the OP back at them.",
    "Honestly the best part of this whole saga has been watching the goalposts move in real time.<br /><br />Twice in one page, even.",
    "Counterpoint: no.",
    "Can we get a mod to retitle this thread? The current title stopped being accurate about forty posts ago.",
    "If you scroll up a bit you'll see this was already covered, with sources, by someone far more patient than me.",
    "I am once again asking people to read the post they are replying to before they reply to it.<br /><br />It would save us all a lot of time.",
]


def post_id(index):
    """Post ID for the post at 1-based `index` in the thread. Mirror of QuoteJumpFixture.postID(forIndex:) in the tests."""
    page = (index - 1) // POSTS_PER_PAGE + 1
    index_on_page = (index - 1) % POSTS_PER_PAGE + 1
    return 900000000 + page * 100 + index_on_page


def quote(index, snippet):
    author = AUTHORS[index % len(AUTHORS)][0]
    pid = post_id(index) if index != DELETED_POST_ID else DELETED_POST_ID
    return (
        '<div class="bbc-block"><h4><a class="quote_link" href="/showthread.php?goto=post&amp;postid=%d#post%d" rel="nofollow">%s posted:</a></h4>'
        '<blockquote>%s</blockquote></div>' % (pid, pid, author, snippet)
    )


def image(name, height, delay_ms):
    return '<img src="{{IMAGE_BASE}}/img/%s.png?delay=%d&amp;h=%d" alt="" border="0">' % (name, delay_ms, height)


def body_for(index):
    if index == 5:
        return "Target five. A short post near the top of page one, quoted from page two."
    if index == 20:
        return "Three big slow images above the next target:<br />%s<br />%s<br />%s" % (
            image("p1-a", 900, 1500), image("p1-b", 900, 1500), image("p1-c", 900, 1500))
    if index == 30:
        return "Target thirty. Everything above this post on page one has to finish loading before the jump can be trusted."
    if index == 42:
        return "Target forty-two. The reader has already seen this post, so it starts out behind Previous Posts."
    if index in (45, 46, 47):
        return "A tall image that loads slowly:<br />%s" % image("p2-%d" % index, 800, 2000)
    if index == 50:
        return "Target fifty. Behind Previous Posts, with three slow images above it once they are shown."
    if index == 55:
        return 'Look at this: <a href="https://twitter.com/jack/status/20">https://twitter.com/jack/status/20</a>'
    if index == 60:
        return "".join([
            quote(42, "The reader has already seen this post"),
            "Yeah, that one was fine.<br /><br />",
            quote(50, "Behind Previous Posts, with three slow images above it"),
            "This is the one everyone keeps missing.<br /><br />",
            quote(70, "Below the tapping post, nothing slow between"),
            "Scroll down a bit.<br /><br />",
            quote(76, "Below the tapping post, three slow images between"),
            "Scroll down a bit further.<br /><br />",
            quote(30, "Everything above this post on page one"),
            "Still true.<br /><br />",
            quote(5, "A short post near the top of page one"),
            "Top of page one, for the record.<br /><br />",
            quote(95, "Ninety-five, in the read part of the last page"),
            "Also covered on the last page.<br /><br />",
            quote(118, "One eighteen, among the unread posts"),
            "And again, more recently.<br /><br />",
            quote(DELETED_POST_ID, "A post that has since been deleted"),
            "Well, that one's gone.",
        ])
    if index == 61:
        return (
            'Spoilers for the ending: <span class="bbc-spoiler" onmouseover="this.style.color=\'#fff\';" onmouseout="this.style.color=\'#000\';" style="background-color:#000;color:#000;">'
            'it was already said in <a href="/showthread.php?goto=post&amp;postid=%d#post%d">this post</a>.</span>' % (post_id(70), post_id(70))
        )
    if index == 70:
        return "Target seventy. Below the tapping post, nothing slow between."
    if index in (72, 73, 74):
        return "A tall image that loads slowly:<br />%s" % image("p2-%d" % index, 800, 2000)
    if index == 76:
        return "Target seventy-six. Below the tapping post with three slow images in between."
    if index == 95:
        return "Target ninety-five. In the read region of the last page once the reader has caught up to 109."
    if index == 110:
        return "Post one hundred and ten. The first unread post on page three once the reader has caught up to 109."
    if index == 115:
        return "Two more slow images:<br />%s<br />%s" % (image("p3-a", 900, 1500), image("p3-b", 900, 1500))
    if index == 118:
        return "Target one eighteen. Among the unread posts on the last page."
    return FILLER[index % len(FILLER)] + "<br /><br />" + FILLER[(index * 3 + 1) % len(FILLER)]


def render_post(index, seen_through):
    name, user_id, regdate = AUTHORS[index % len(AUTHORS)]
    pid = post_id(index)
    seen_class = ' class="seen%d"' % (1 + index % 2) if index <= seen_through else ""
    op_class = " op" if index == 1 else ""
    minute = index % 60
    hour = 9 + (index // 60)
    return """<table class="post " id="post%(pid)d" data-idx="%(index)d">
<tr %(seen)s id="pti%(index_on_page)d">
\t<td class="userinfo userid-%(user_id)d">
\t\t<dl class="userinfo">
\t\t\t<dt class="author%(op)s" title="">%(name)s</dt>
\t\t\t<dd class="registered">%(regdate)s</dd>
\t\t\t<dd class="title">
\t\t\t\t<br class="pb">
\t\t\t</dd>
\t\t</dl>
\t</td>
\t<td class="postbody">
\t\t<!-- BeginContentMarker -->
\t\t%(body)s
\t\t<!-- EndContentMarker -->
\t\t<p class="editedby">
\t</td>
</tr>
<tr%(seen)s>
\t<td class="postdate">
\t\t<a class="lastseen_icon" href="/showthread.php?action=setseen&amp;threadid=%(thread_id)d&amp;index=%(index)d" title="Mark all replies as read to this point"><img src="http://fi.somethingawful.com/style/posticon-seen.gif" alt="" border="0"></a>
\t\t<a href="#post%(pid)d" title="Link to this post">#</a>
\t\t<a class="user_jump" title="Show posts by this user" href="/showthread.php?threadid=%(thread_id)d&amp;userid=%(user_id)d">?</a>
\t\tJan 2, 2026 %(hour)02d:%(minute)02d
\t</td>
\t<td class="postlinks">
\t\t<ul class="profilelinks">
\t\t\t<li><a href="member.php?action=getinfo&amp;userid=%(user_id)d">Profile</a></li>
\t\t\t<li><a href="private.php?action=newmessage&amp;userid=%(user_id)d">Message</a></li>
\t\t\t<li><a href="search.php?action=do_search_posthistory&amp;userid=%(user_id)d">Post History</a></li>
\t\t</ul>
\t\t<ul class="postbuttons">
\t\t\t<li class="alertbutton"><a href="modalert.php?postid=%(pid)d&amp;username=%(name_escaped)s"><img src="http://forumimages.somethingawful.com/images/button-report.gif" border="0" alt="Alert Moderators"></a>&nbsp;&nbsp;</li>
\t\t\t<li><a href="newreply.php?action=newreply&amp;postid=%(pid)d"><img src="http://fi.somethingawful.com/images/sa-quote.gif" alt="Quote"  title=""></a></li>
\t\t</ul>
\t</td>
</tr>
</table>""" % {
        "pid": pid,
        "index": index,
        "index_on_page": (index - 1) % POSTS_PER_PAGE + 1,
        "seen": seen_class,
        "user_id": user_id,
        "op": op_class,
        "name": name,
        "name_escaped": url_quote(name),
        "regdate": regdate,
        "body": body_for(index),
        "thread_id": THREAD_ID,
        "hour": hour,
        "minute": minute,
    }


def render_pages_nav(page, position):
    base = "showthread.php?threadid=%d&amp;userid=0&amp;perpage=%d" % (THREAD_ID, POSTS_PER_PAGE)
    options = "".join(
        '<option value="%d"%s>%d</option>' % (n, ' selected="selected"' if n == page else "", n)
        for n in range(1, PAGE_COUNT + 1)
    )
    parts = ['<div class="pages %s">' % position]
    if page > 1:
        parts.append('<a href="%s&pagenumber=1" title="First page">&laquo;</a>' % base)
        parts.append('<a href="%s&pagenumber=%d" title="Previous page">&lsaquo;</a>' % (base, page - 1))
    parts.append('<select data-url="%s">%s</select>' % (base, options))
    if page < PAGE_COUNT:
        parts.append('<a href="%s&pagenumber=%d" title="Next page">&rsaquo;</a>' % (base, page + 1))
        parts.append('<a href="%s&pagenumber=%d" title="Last page">%d &raquo;</a>' % (base, PAGE_COUNT, PAGE_COUNT))
    parts.append("</div>")
    return "".join(parts)


def render_breadcrumbs():
    return (
        '<div class="breadcrumbs"><span class="mainbodytextlarge"><b><a href="/">The Something Awful Forums</a> &gt; '
        '<a href="forumdisplay.php?forumid=48">Main</a> &gt; '
        '<a href="forumdisplay.php?forumid=%d">General Bullshit</a> &gt; '
        '<a href="showthread.php?threadid=%d" class="bclast">%s</a></b></span></div>' % (FORUM_ID, THREAD_ID, THREAD_TITLE)
    )


def render_threadbar(position):
    return """<div class="threadbar %(position)s">
<ul class="postbuttons">
\t<li><img src="http://fi.somethingawful.com/images/buttons/button-bookmark.png" alt="" class="thread_bookmark bookmark"></li>
\t<li><a href="newthread.php?action=newthread&amp;forumid=%(forum_id)d"><img src="http://fi.somethingawful.com/images/forum-post.gif" alt="Post" title=""></a></li>
\t<li><a href="newreply.php?action=newreply&amp;threadid=%(thread_id)d"><img src="http://fi.somethingawful.com/images/forum-reply.gif" alt="Reply" title=""></a></li>
</ul>
</div>""" % {"position": position, "forum_id": FORUM_ID, "thread_id": THREAD_ID}


def render_page(page, seen_through):
    first = (page - 1) * POSTS_PER_PAGE + 1
    posts = "".join(render_post(i, seen_through) for i in range(first, first + POSTS_PER_PAGE))
    return """<!DOCTYPE html>
<html lang="en">
<head>
\t<meta charset="utf-8">
\t<title>%(title)s - The Something Awful Forums</title>
\t<meta name="Description" content="%(title)s">
\t<!-- Generated by Scripts/make-quotejump-fixtures.py; edit that script, not this file. -->
</head>
<body id="something_awful" class="showthread forum_%(forum_id)d thread_%(thread_id)d" data-forum="%(forum_id)d" data-thread="%(thread_id)d">

<div id="top"></div>

<div id="container">

\t<ul id="navigation" class="navigation">
<li class="first"><a href="/index.php">SA Forums</a></li>
<li>- <a href="/usercp.php">User Control Panel</a></li>
<li>- <a href="/account.php?action=logout&amp;ma=d9ee4564">Log Out</a></li>
</ul>

\t<div id="content">

%(pages_top)s
%(breadcrumbs)s
%(threadbar_top)s
<div id="thread" class="thread:%(thread_id)d">
%(posts)s
</div>
%(threadbar_bottom)s
%(pages_bottom)s
%(breadcrumbs)s

</div><!-- #content -->

\t<div id="copyright">
\t\tPowered by: vBulletin Version 2.2.9 (<a href="/CHANGES">SAVB-v2.1.17</a>)<br>
\t\tCopyright &copy;2000, 2001, Jelsoft Enterprises Limited.<br>
\t\tCopyright &copy;2026, Something Awful LLC<br>
\t</div>

</div><!-- #container -->

<ol id="debug" style="display:none"><li>&nbsp;</ol>

</body>
</html>
""" % {
        "title": THREAD_TITLE,
        "forum_id": FORUM_ID,
        "thread_id": THREAD_ID,
        "pages_top": render_pages_nav(page, "top"),
        "pages_bottom": render_pages_nav(page, "bottom"),
        "breadcrumbs": render_breadcrumbs(),
        "threadbar_top": render_threadbar("top"),
        "threadbar_bottom": render_threadbar("bottom"),
        "posts": posts,
    }


VARIANTS = [
    # (filename, page, seen through)
    ("quotejump-p1.html", 1, 59),
    ("quotejump-p2.html", 2, 59),
    ("quotejump-p3.html", 3, 59),
    ("quotejump-p3-seen109.html", 3, 109),
    ("quotejump-p3-seen119.html", 3, 119),
]


def main():
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--out", default=os.path.join(repo, "AwfulCore", "Tests", "AwfulCoreTests", "Fixtures"),
                        help="directory to write the fixtures into (default: AwfulCore/Tests/AwfulCoreTests/Fixtures)")
    args = parser.parse_args()

    for filename, page, seen_through in VARIANTS:
        html = render_page(page, seen_through)
        html.encode("ascii")  # keep the fixtures encoding-agnostic
        path = os.path.join(args.out, filename)
        with open(path, "w", encoding="ascii", newline="\n") as f:
            f.write(html)
        print("wrote %s (%d bytes)" % (os.path.relpath(path, repo), len(html)), file=sys.stderr)


if __name__ == "__main__":
    main()
