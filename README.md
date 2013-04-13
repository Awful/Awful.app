Awful
=====

Awful is a universal iOS app for browsing the [Something Awful Forums][forums]. Its story is told in [its thread][current thread] (and [its older thread][second thread] and [its first thread][first thread]).

[forums]: http://forums.somethingawful.com
[current thread]: http://forums.somethingawful.com/showthread.php?threadid=3510131
[second thread]: http://forums.somethingawful.com/showthread.php?threadid=3381510
[first thread]: http://forums.somethingawful.com/showthread.php?threadid=3483760

An unofficial app
-----------------

This app is not endorsed by Something Awful.

Build
-----

[![Build Status](https://travis-ci.org/AwfulDevs/Awful.png)](https://travis-ci.org/AwfulDevs/Awful)

1. Clone the repository: `git clone https://github.com/AwfulDevs/Awful.git`
2. Open Xcode project and build away: `cd Awful && open Awful.xcodeproj`

Debug builds, beta builds, and release builds each appear as separate apps (they have different bundle identifiers and display names). To build for the App Store, change the scheme to "Awful App Store", then choose `Archive` from the `Product` menu.

There are no required dependencies for building Awful; all third-party libraries are included.

There are optional dependencies for building Awful. You only need them if you're working on the relevant part of the app. Once a dependency is installed, simply build the Xcode project and the relevant files will be regenerated.

* [LESS][] helps us write CSS. If you're modifying the themes for displaying posts (these are files like `posts-view*.less`), please [install LESS][LESS]:
    1. [Install homebrew](http://mxcl.github.com/homebrew/).
    2. Open Terminal and install node: `brew install node` (prepend `sudo` to avoid permissions errors).
    3. In Terminal, install less: `npm install less -g` (prepend `sudo` to avoid permissions errors).
* [mogenerator][] makes Objective-C classes from our Core Data model. If you're modifying the Core Data model (aka `Model.xcdatamodeld`), please [install mogenerator][mogenerator].

If you want to use Crashlytics, create a file called `crashlytics-api-key` containing your API key.

[LESS]: http://lesscss.org/#usage
[mogenerator]: http://rentzsch.github.com/mogenerator/

Contribute
----------

You can help! Head over to [Awful's thread][current thread] and tell us about any issues you're having. Send in some lovingly crafted [thread tags][]. Or [fork the code][fork] and send [pull requests][]. If you're curious about anything at all, stop by the [thread][current thread] and say hi.

[thread tags]: https://github.com/AwfulDevs/Awful/blob/master/Resources/Thread%20Tags/README.md#thread-tags
[fork]: https://github.com/AwfulDevs/Awful/fork_select
[pull requests]: https://github.com/AwfulDevs/Awful/pulls

Data Flow
---------

The [HTTP client][] connects to the Something Awful Forums and parses its contents, saving those contents as [entities in a Core Data store][entities]. Various screens show the [forums][], [threads][], [posts][], [private messages][], and [users][] saved to the Core Data store.

Awful's Core Data store is a cache of content from the Forums. Any user info specific to the app is stored in [user defaults][]. The Core Data store can be (and may be, since it's stored in the application's Caches directory) deleted at any time.

[HTTP client]: Source/Networking/AwfulHTTPClient.h
[entities]: Source/Models
[forums]: Source/Forums
[threads]: Source/Threads
[posts]: Source/Posts
[private messages]: Source/Private%20Messages
[users]: Source/Users
[user defaults]: Source/Settings/AwfulSettings.h

Theming
-------

Awful's [posts view][] is fully customizable using CSS. There's a [default theme][], as well as themes for specific forums such as [YOSPOS][YOSPOS CSS theme] and [FYAD][FYAD CSS theme]. Users can include their own custom themes by adding specially-named CSS files to the application Documents directory; [more info][custom CSS readme]. Internally, we use LESS to generate our CSS, so if you are editing built-in themes please edit the `.less` files. (LESS installation instructions are above.)

The rest of Awful's screens support much more limited theming for the "dark mode" setting. The color schemes are set in [AwfulTheme][]; there is no way to override them.

[posts view]: Source/Posts/AwfulPostsView.h
[default theme]: Source/Theming/posts-view.css
[YOSPOS CSS theme]: Source/Theming/posts-view-219.less
[FYAD CSS theme]: Source/Theming/posts-view-26.less
[custom CSS readme]: Resources/Custom%20CSS%20README.txt
[AwfulTheme]: Source/Theming/AwfulTheme.h

License
-------

[Creative Commons Attribution-NonCommercial-ShareAlike 3.0 United States License](http://creativecommons.org/licenses/by-nc-sa/3.0/us/)

Credit
------

Awful development is led by [pokeyman][] aka [Nolan Waite](https://github.com/nolanw).

Awful includes contributions from:

- [Diabolik900](http://forums.somethingawful.com/member.php?action=getinfo&userid=113215)
- [enigma105](http://forums.somethingawful.com/member.php?action=getinfo&userid=51258)
- [hardstyle](http://forums.somethingawful.com/member.php?action=getinfo&userid=51070)
- [pokeyman][]
- [Malcolm XML](http://forums.somethingawful.com/member.php?action=getinfo&userid=154586)
- [OHIO](http://forums.somethingawful.com/member.php?action=getinfo&userid=82915)
- [The Dave](http://forums.somethingawful.com/member.php?action=getinfo&userid=41741)
- [ultramiraculous](http://forums.somethingawful.com/member.php?action=getinfo&userid=44504)
- [xzzy](http://forums.somethingawful.com/member.php?action=getinfo&userid=148096)

[pokeyman]: http://forums.somethingawful.com/member.php?action=getinfo&userid=106125
