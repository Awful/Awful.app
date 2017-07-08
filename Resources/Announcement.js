//  Announcement.js
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// This file is loaded as a user script "at document end" into the `WKWebView` that renders announcements. `RenderView.js` will also be loaded, so you have those functions at your disposal.

if (!window.Awful) {
    window.Awful = {};
}

/**
 Replaces the announcement HTML.
 
 @param {string} html - The updated HTML for the announcement.
 */
window.Awful.setAnnouncementHTML = function(html) {
    var post = document.querySelector('post');
    if (post) {
        post.remove();
    }

    document.body.insertAdjacentHTML('beforeend', html);
};
