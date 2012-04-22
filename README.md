Awful
=====

Awful is an iOS app for browsing the [Something Awful Forums][forums] on your iPhone or iPad. Some of its story can be found in its [thread][].

[forums]: http://forums.somethingawful.com
[thread]: http://forums.somethingawful.com/showthread.php?threadid=3381510

For this release
----------------
**HEY THIS IS SEAN**
I'm going to work on copying thread url, intra-forum links, press/hold to go first/last page, bar button items for reply box, and the bold issue. Then I'm going to take a look at your branches and hook that shit up

* Populate forums list and bookmarks immediately from local cache. Update when fetch/parse is complete.
* Don't try to fetch bookmarks when not logged in.
* Fix bold issue (currently example in awfulapp thread)
* Sane intro to the app, take user to login screen
* Default data set with current forums (why do we need this? it's not much data)
* rearrange favorite forums
* press-hold on threadlist to jump to first/last page of a thread from threadlist
* Copy thread/post URL
* Maintain page position on orientation change
* Smarter iPad interface
* Pick and include a license.
* Turn the code loose once more.

For some later release
----------------------
* Private messages
* Search
* FYAD

An unofficial app
-----------------

This app is unofficial and is not endorsed by Lowtax. Use at your own risk.

Build
-----

1. Grab code: `git clone https://github.com/regularberry/Awful.git`
2. Open Xcode project and build away: `open Awful.xcodeproj`

Contribute
----------

We welcome any feedback, issues, or pull requests. Thanks!

License
-------

GPLv2. If this license does not work for you, we can make arrangements.

Credit
------

Awful is developed by [Sean Berry][regularberry] with some help from his friends.

[regularberry]: https://github.com/regularberry
