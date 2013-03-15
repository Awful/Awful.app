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

1. Clone the repository: `git clone https://github.com/AwfulDevs/Awful.git`
2. Open Xcode project and build away: `cd Awful && open Awful.xcodeproj`

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
- [xzzy](http://forums.somethingawful.com/member.php?action=getinfo&userid=148096)

[pokeyman]: http://forums.somethingawful.com/member.php?action=getinfo&userid=106125
