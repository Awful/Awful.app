//  RenderView.js
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// This file is loaded as a user script "at document end" into the `WKWebView` that renders announcements, posts, and private messages.

document.body.addEventListener('click', Awful.handleClickEvent);

// TODO: imgurGif, .gifWrap, rectOfElement, interestingElementsAtPoint, didTapUserHeader, didTapActionButton, highlightMentions (?), HeaderRectForPostAtIndex (?), FooterRectForPostAtIndex (?), ActionButtonRectForPostAtIndex (?). some of the ones marked ? mention synchronous calls, that's no longer a thing for WKWebView so let's preempt that if we can

if (!window.Awful) {
    window.Awful = {};
}


/**
 Scrolls the document past a fraction of the document.

 @param {number} fraction - A number between 0 and 1, where 0 is the top of the document and 1 is the bottom.
 */
Awful.jumpToFractionalOffset = function(fraction) {
    window.scroll(0, document.body.scrollHeight * fraction);
};


/**
 Handles any click event, including:

     * Loading linkified images.
     * Revealing spoilers.

 @param {Event} event - A click event.
 */
Awful.handleClickEvent = function(event) {
    // Toggle spoilers on tap.
    var spoiler = event.target.closest('.bbc-spoiler');
    if (spoiler) {
        var isSpoiled = spoiler.classList.contains("spoiled");
    
        var nearestLink = event.target.closest('a, [data-awful-linkified-image]');
        var isLink = !!nearestLink;
    
        if (!(isLink && isSpoiled)) {
            spoiler.classList.toggle("spoiled");
            event.preventDefault();
        }
        else if (isLink && !isSpoiled) {
            event.stopImmediatePropagation();
            event.preventDefault();
        }
        return;
    }
    
    // Show linkified images on tap.
    var link = event.target;
    if (link.dataset.awfulLinkifiedImage) {
        var img = document.createElement('img');
        img.setAttribute('alt', "");
        img.setAttribute('border', "0");
        img.setAttribute('src', link.textContent);

        link.parentNode.replaceChild(img, link);

        event.preventDefault();
        return;
    }
    
    // Tap on post header to reveal actions on the poster.
    var header = event.target.closest('header');
    var postIndex;
    if (header && (postIndex = Awful.postIndexOfElement(header)) !== null) {
        var frame = Awful.frameOfElement(header);
        
        window.webkit.messageHandlers.didTapAuthorHeader.postMessage({
            "frame": frame,
            "postIndex": postIndex
        });
        
        event.preventDefault();
        return;
    }
    
    var button = event.target.closest('button.action-button');
    var postIndex;
    if (button && (postIndex = Awful.postIndexOfElement(button)) !== null) {
        var frame = Awful.frameOfElement(button);
        
        window.webkit.messageHandlers.didTapPostActionButton.postMessage({
            "frame": frame,
            "postIndex": postIndex
        });
        
        event.preventDefault();
        return;
    }
};


/**
 @typedef ElementRect
 @type {object}
 @property {number} x - The horizontal component of the rectangle's origin.
 @property {number} y - The vertical component of the rectangle's origin.
 @property {number} width - The width of the rectangle.
 @property {number} height - The height of the rectangle.
 */


/**
 Returns the frame of an element in the web view's scroll view's coordinate system.

 @param {Element} element - An element in the document.
 @returns {ElementRect} The element's frame, or a rectangle with zero area if the element's border boxes are all empty.
 */
Awful.frameOfElement = function(element) {
    var rect = element.getBoundingClientRect();
    return {
        "x": window.scrollX + rect.left,
        "y": window.scrollY + rect.top,
        "width": rect.width,
        "height": rect.height
    };
};


/**
 Returns the index of the post that contains the element, if any. The element can be a `<post>` element or appear in any subtree of a `<post>` element.

 @param {Element} element - An element in the document.
 @returns {?number} The index of the post where `element` appears, where `0` is the first post in the document; or `null` if `element` is not in a `<post>` element.
 */
Awful.postIndexOfElement = function(element) {
    var post = element.closest('post');
    if (!post) {
        return null;
    }
    
    var i = 0;
    var curr = post.previousElementSibling;
    while (curr) {
        if (curr.nodeName === "POST") {
            i += 1;
        }
        curr = curr.previousElementSibling;
    }
    
    return i;
};


/**
 Updates the user-specified font scale setting.
 
 @param {number} percentage - The user's selected font scale as a percentage.
 */
Awful.setFontScale = function(percentage) {
    var style = document.getElementById('awful-font-scale-style');
    if (!style) { 
        return; 
    }

    if (percentage == 100) {
        style.textContent = '';
    }
    else {
        style.textContent = ".nameanddate, .postbody, footer { font-size: " + percentage + "%; }";
    }
};


/**
 Updates the user-specified setting to show avatars.
 
 @param {boolean} showAvatars - `true` to show user avatars, `false` to hide user avatars.
 */
Awful.setShowAvatars = function(showAvatars) {
    if (showAvatars) {
        var headers = document.querySelectorAll('header[data-awful-avatar]');
        for (var i = 0, end = headers.length; i < end; i++) {
            var header = headers[i];
            var img = document.createElement('img');
            img.classList.add("avatar");
            img.setAttribute('alt', "");
            img.setAttribute('src', header.dataset.awfulAvatar);
            header.insertBefore(img, header.firstChild);

            header.removeAttribute('data-awful-avatar');

            var post = header.closest('post');
            if (post) {
                post.classList.remove("no-avatar");
            }
        }
    }
    else {
        var imgs = document.querySelectorAll('header img.avatar');
        for (var i = 0, end = imgs.length; i < end; i++) {
            var img = imgs[i];
            var header = img.closest('header');
            if (header) {
                header.dataset.awfulAvatar = img.getAttribute('src');
            }

            var post = img.closest('post');
            if (post) {
                post.classList.add("no-avatar");
            }

            img.remove();
        }
    }
};


/**
 Updates the stylesheet for the currently-selected theme.

 @param {string} css - The replacement stylesheet from the new theme.
 */
Awful.setThemeStylesheet = function(css) {
    var style = document.getElementById('awful-inline-style');
    if (!style) { return; }
    style.textContent = css;
};


// THIS SHOULD STAY AT THE BOTTOM OF THE FILE!
// All done; tell the native side we're ready.
window.webkit.messageHandlers.didRender.postMessage({});
