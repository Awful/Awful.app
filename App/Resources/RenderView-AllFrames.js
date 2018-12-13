//  RenderView-AllFrames.js
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/*
 This file is loaded as a user script "at document end" into all frames of the `WKWebView` that renders announcements, posts, profiles, and private messages. It is loaded into all frames, not just the main frame.

To add features to RenderView, you should probably look at `RenderView.js` first; this file is for scripts that we'd like to run in iframes too.

Remember that this script runs in the main frame too, so be careful not to mess with RenderView functionality.
*/

;(function(){

  // Prevent default WKWebView long-press link menu in iframes. Otherwise it presents an action sheet which denies our ability to present our own action sheet on long-press.
  var bodyStyle = window.getComputedStyle(document.body);
  if (bodyStyle.getPropertyValue('-webkit-touch-callout') === "default") {
    document.body.style.webkitTouchCallout = "none";
  }

})()
