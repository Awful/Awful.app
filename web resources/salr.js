
// Copyright (c) 2009, Scott Ferguson
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the software nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY SCOTT FERGUSON ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL SCOTT FERGUSON BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

function SALR(preferences) {
    this.preferences = preferences;

    this.init();
};

SALR.prototype.init = function() {
    if (this.preferences.highlightUsername == "true") {
        this.highlightOwnUsername();
    }

    if (this.preferences.highlightUserQuote == "true") {
        this.highlightOwnQuotes();
    }
    
	if (this.preferences.imagesEnabled == "false") {
        this.replaceImagesWithLinks();
	}

	// this.modifyImages();
    // this.inlineYoutubes();
    // this.highlightFriendPosts();    
    // this.highlightOPPosts();    
    // this.highlightOwnPosts();
    // this.highlightModAdminShowThread();
};

SALR.prototype.modifyImages = function() {
	// fix timg, because it's broken
	if(this.preferences.fixTimg == 'true') this.fixTimg(this.preferences.forceTimg == 'true');
	
	// Replace Links with Images
	if (this.preferences.replaceLinksWithImages == 'true') {

		var subset = $('.postbody a');

		//NWS/NMS links
		if(this.preferences.dontReplaceLinkNWS == 'true')
		{
			subset = subset.not(".postbody:has(img[title=':nws:']) a").not(".postbody:has(img[title=':nms:']) a");
		}

		// spoiler'd links
		if(this.preferences.dontReplaceLinkSpoiler == 'true') {
			subset = subset.not('.bbc-spoiler a');	
		}

		// seen posts
		if(this.preferences.dontReplaceLinkRead == 'true') {
			subset = subset.not('.seen1 a').not('.seen2 a');
		}

		subset.each(function() {

			var match = $(this).attr('href').match(/https?\:\/\/(?:[-_0-9a-zA-Z]+\.)+[a-z]{2,6}(?:\/[^/#?]+)+\.(?:jpe?g|gif|png|bmp)/);
			if(match != null) {
				$(this).after("<img src='" + match[0] + "' />");
				$(this).remove();
			}
		});
	}

	if (this.preferences.restrictImageSize == 'true') {
		$('.postbody img').each(function() {
            var width = $(this).width();
            var height = $(this).height();

            $(this).click(function() {
                if ($(this).width() == '800') {
                    $(this).css({
                        'max-width': width + 'px',
                    });
                } else {
                    $(this).css({'max-width': '800px'});
                }
            });

            if ($(this).width() > '800') {
                $(this).css({
                    'max-width': '800px',
                    'border': '1px dashed gray'
                });
            }
        });
	}
};

SALR.prototype.replaceImagesWithLinks = function() {
    var subset = $('.post-content img');
    
    subset = subset.not('img[src*=http://i.somethingawful.com/forumsystem/emoticons/]');
    subset = subset.not('img[src*=http://fi.somethingawful.com/images/smilies/]');

    subset.each(function() {
        var source = $(this).attr('src');
        $(this).after("<a href='" + source + "'>" + source + "</a>");
        $(this).remove();
    });
};

SALR.prototype.inlineYoutubes = function() {
    var that = this;

	//sort out youtube links
	$('.postbody a[href*="youtube.com"]').each(function() {
			$(this).css("background-color", that.preferences.youtubeHighlight).addClass("salr-video");
	});
	
	$(".salr-video").toggle(function(){ 
			var match = $(this).attr('href').match(/^http\:\/\/((?:www|[a-z]{2})\.)?youtube\.com\/watch\?v=([-_0-9a-zA-Z]+)/); //get youtube video id
			var videoId = match[2];

            $(this).after('<iframe class="salr-player youtube-player"></iframe>');
			$(".salr-player").attr("src", "http://www.youtube.com/embed/" + videoId);
			$(".salr-player").attr("width","640");
			$(".salr-player").attr("height","385");
			$(".salr-player").attr("type","text/html");
			$(".salr-player").attr("frameborder","0");

			return false;
		},
		function() {
			// second state of toggle destroys player. should add a check for player existing before 
            // destroying it but seing as it's the second state of a toggle i'll leave it for now. 
			$(this).next().remove();
		}
	);
};

/**
 * Highlight the posts of friends
 */
SALR.prototype.highlightFriendPosts = function() {
    var that = this;
    if (!this.preferences.friendsList)
        return;
    var friends = JSON.parse(this.preferences.friendsList);
    var selector = '';

    if (friends == 0) {
        return;
    }

    $(friends).each(function() {
        if (selector != '') {
            selector += ', ';
        }
        selector += "dt.author:econtains('" +  this + "')";
    });

    $('table.post:has('+selector+') td').each(function () {
        $(this).css({
            'border-collapse' : 'collapse',
            'background-color' : that.preferences.highlightFriendsColor
        });
    });
};

/**
 * Highlight the posts by the OP
 */
SALR.prototype.highlightOPPosts = function() {
    var that = this;

    $('table.post:has(dt.author.op) td').each(function () {
        $(this).css({
            'border-collapse' : 'collapse',
            'background-color' : that.preferences.highlightOPColor
        });
    });
    $('dt.author.op').each(function() {
        $(this).after(
            '<dd style="color: #07A; font-weight: bold; ">Thread Poster</dd>'
        );
    });
};

/**
 * Highlight the posts by one self
 */
SALR.prototype.highlightOwnPosts = function() {
    var that = this;

    $("table.post:has(dt.author:econtains('"+that.preferences.username+"')) td").each(function () {
        $(this).css({
            'border-collapse' : 'collapse',
            'background-color' : that.preferences.highlightSelfColor
        });
    });
};

/**
 * Highlight the posts by moderators and admins
 * on the who posted page
 */
SALR.prototype.highlightModAdminWhoPosted = function() {
    var that = this;

    if (this.preferences.modList == null)
        return;

    var modList = JSON.parse(this.preferences.modList);

    $('a[href*=member.php]').each(function() {
        var userid = $(this).attr('href').split('userid=')[1];
        if (modList[userid] != null) {
            var color;
            switch (modList[userid].mod) {
                case 'M':
                    color = that.preferences.highlightModeratorColor;
                    break;
                case 'A':
                    color = that.preferences.highlightAdminColor;
                    break;
            }
            $(this).css('color', color);
            $(this).css('font-weight', 'bold');
        }
    });
};

/**
 * Highlight the user's username in posts
 */
SALR.prototype.highlightOwnUsername = function() {
    function getTextNodesIn(node) {
        var textNodes = [];

        function getTextNodes(node) {
            if (node.nodeType == 3) {
                textNodes.push(node);
            } else {
                for (var i = 0, len = node.childNodes.length; i < len; ++i) {
                    getTextNodes(node.childNodes[i]);
                }
            }
        }

        getTextNodes(node);
        return textNodes;
    }

    var that = this;

    var selector = 'div.post-content:contains("' + this.preferences.username + '")';
    
    var re = new RegExp(this.preferences.username, 'g');
    var styled = '<span class="usernameHighlight" style="font-weight: bold; color: ' + that.preferences.usernameHighlight + ';">' + that.preferences.username + '</span>';
    $(selector).each(function() {
        getTextNodesIn(this).forEach(function(node) {
            if(node.wholeText.match(re)) {
                newNode = node.ownerDocument.createElement("span");
                $(newNode).html(node.wholeText.replace(re, '<span class="usernameHighlight" style="font-weight: bold; color: ' + that.preferences.usernameHighlight + ';">' + that.preferences.username + '</span>'));
                node.parentNode.replaceChild(newNode, node);
            }
        });
    });
};

/**
 * Highlight the quotes of the user themselves.
 */
SALR.prototype.highlightOwnQuotes = function() {
    var that = this;

    var usernameQuoteMatch = that.preferences.username + ' posted:';
    $('.bbc-block h4:contains(' + usernameQuoteMatch + ')').each(function() {
        if ($(this).text() != usernameQuoteMatch)
            return;
        $(this).parent().css("background-color", that.preferences.userQuote);

        // Replace the styling from username highlighting
        var previous = $(this);
        $('.usernameHighlight', previous).each(function() {
            $(this).css('color', '#555');
        });
    });
};
