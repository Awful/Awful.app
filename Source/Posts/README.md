# Assembling the AwfulPostsView

We use a few JavaScript libraries for AwfulPostsView. Here's how to build them.

## [zepto][]

jQuery for modern browsers.

`$ rake concat[-polyfill:-detect:-fx:-form:touch] dist`

Then move `dist/zepto.min.js` to this folder.

[zepto]: https://github.com/madrobby/zepto

## [mustache.js][]

Logic-less templates.

`$ rake jquery`

Then move `jquery.mustache.js` to this folder.

[mustache.js]: https://github.com/janl/mustache.js

## Final assembly

Concatenate these files together into a single file, `posts-view.js`. This file is loaded by AwfulPostsView.

`$ rake`

We also make Zepto available globally as `jQuery`, so the mustache.js plugin works unmodified.
