# Awful

[Awful][App Store] is an iOS 15.0+ app that's *Better Than Safari* for browsing the [Something Awful Forums][forums]. Its story is told in [its thread][current thread] (and the [thread before that][third thread] (and [the thread before that][second thread] (and [the thread before that][first thread]))).

Not sure what to work on? There's a [list of issues](https://github.com/awful/Awful.app/issues), or just post in the thread and someone will share their pet peeves for your amusement!

<p align="center">
  <img src="Screenshots/Awful/iPhone 6.5in.png" width="414" height="896" alt="Screenshot of Awful as it appears on an iPhone">
</p>

[App Store]: https://itunes.apple.com/app/awful-unofficial-something/id567936609
[forums]: http://forums.somethingawful.com
[current thread]: https://forums.somethingawful.com/showthread.php?threadid=3837546
[third thread]: http://forums.somethingawful.com/showthread.php?threadid=3510131
[second thread]: http://forums.somethingawful.com/showthread.php?threadid=3381510
[first thread]: http://forums.somethingawful.com/showthread.php?threadid=3483760
[project.log]: http://forums.somethingawful.com/showthread.php?threadid=3564303

## An unofficial app

This app is not endorsed by Something Awful.

## Build

Please drop by [the thread][current thread] if you could use a hand with any of these steps!

You need Xcode 15 to build and run Awful. You can [download Xcode for free from Apple](https://developer.apple.com/download/). Then:

1. Clone the repository: `git clone --recursive https://github.com/Awful/Awful.app Awful-app`
2. Open the Xcode project and build away: `xed Awful-app`

You may see build warnings of the form "Unable to find included file '../Local.xcconfig'". You should still be able to build and run, just with a couple of features turned off. If you'd like to enable those features, or just make the warnings go away, please scroll on down to the "Local build settings" section below.

The only required dependencies for building Awful that are not included directly in this repository are those managed by Swift Package Manager. Files generated by other utilities are included in the repository. The only submodule is the [thread-tags][] repository, which is not strictly needed for building; if you don't need it, you can leave off the `--recursive` part from step one.

If you'd like to build to your device, set the `DEVELOPMENT_TEAM` build setting as mentioned in the Local build settings section below.

[thread-tags]: https://github.com/Awful/thread-tags

### Local build settings

There are some local build settings that can be useful to include but should not be committed to a public repo. Store those in an Xcode configuration file at `Local.xcconfig`; see [Local.sample.xcconfig](Local.sample.xcconfig) for an example. You'll get a build warning until you put a file at that location; it can be an empty file if you just want Xcode to be quiet.

Awful uses an App Group to communicate and share data with the Smilie Keyboard. Unfortunately, App Group identifiers must be unique, so we can't simply set it up in this repository and have it work for everybody work. By default, Awful builds without an App Group configured, which means that the Smilie Keyboard won't be able to download new smilies, remember recent smilies, or store favourite smilies. If you like, you can:

1. Create an App Group in your iOS Developer account.
2. Copy `Local.sample.entitlements` to `Local.entitlements`.
3. Copy and paste your App Group identifier into `Local.entitlements`.
4. Set the `CODE_SIGN_ENTITLEMENTS` build setting in `Local.xcconfig` for the targets `Awful` and `SmilieKeyboard` (see `Local.sample.xcconfig` for a suggested setup).
5. After a build and run, full keyboard functionality should be yours.

### Tests

There are unit tests, that don't cover much, running continuously via [GitHub Actions](https://github.com/Awful/Awful.app/actions?query=workflow%3ACI).

[![Build Status](https://github.com/Awful/Awful.app/workflows/CI/badge.svg)](https://github.com/Awful/Awful.app/actions?query=workflow%3ACI)

### Updating dependencies

Dependencies not managed via Swift Package Manager are placed in the [Vendor](Vendor) folder and manually kept up-to-date. They include:

* ARChromeActivity and TUSafariActivity assets. We've implemented our own `UIActivity` subclasses but continue to use the libraries' images.
* JavaScript bits used in the web view for rendering: lottie-player.js.
* MRProgress, PSMenuItem, and PullToRefresh, which do not have their own `Package.swift`. (If you know otherwise, let's move it over!)

See [Vendor/README.md]() for more detailed info about updating these dependencies.

### Version scheme

Bump the major version when changing the minimum required iOS version (deployment target). Otherwise, bump the minor version.

Also, when changing the iOS deployment target, please tag the last commit that supports any no-longer-supported deployment target(s) and update the table in the section "iOS deployment targets" below.

### Handy utilities

If you peek in the [Scripts](Scripts) folder you'll find:

* `beta`, a script that bumps the build number and then runs `xcodebuild` to create an archive suitable for uploading to App Store Connect. See `beta --help` for more, including how to set up automatic uploads to App Store Connect.
    * If you've released to the App Store, it's time to bump at least the minor version number by passing the `--minor`  parameter, e.g. `beta --minor`.
* `bump`, a script that can increment the build, minor, or major version number throughtout the project. See `bump --help` for more.

And in the Xcode project itself you'll find:

* `SmilieExtractor`, an iOS app that takes `showsmilies.webarchive` and extracts resources for Smilie Keyboard. To update smilies, first save a fresh `showsmilies.webarchive` from the Forums, then run `SmilieExtractor`.
* `CopyMarkdownApp`, a macOS Safari App Extension that adds a "Copy Awful Markdown" context menu item to the Forums. The copied markdown is ready to be pasted into a GitHub issue. 

### Loading fixtures into the app and/or working offline

If you've stashed some .html files from the Forums, you can load those into a debug build of the app. And if you forgot to stash some, you're in luck: we've stashed some as test fixtures. See [FixtureURLProtocol](Core/Networking/FixtureURLProtocol.swift) for more info.

## Contribute

You can help! See our [contribution guidelines](CONTRIBUTING.md) and please come visit [the thread][current thread] to say hi.

### Project Structure

Awful is broken down somewhat:

* `Awful` is the iOS app.
* `AwfulCore` is a Swift package that does the scraping and networking with the Forums. It's meant to be compatible with all Apple platforms, but nobody's really tried beyond iOS.
* `Smilies` is a Swift package that downloads smilies and presents them as a keyboard. It's meant to be compatible with all Apple platforms, but nobody's really tried beyond iOS.

### Theming

Awful's [posts view][] is fully customizable using CSS. There's a [default theme][], as well as themes for specific forums such as [YOSPOS][YOSPOS CSS theme] and [FYAD][FYAD CSS theme]. We use [Less][lesscss] to generate our stylesheets during Awful's build process, so you'll want to edit `.less` files but you'll see `.css` files in the build products and in the Web Inspector.

The rest of Awful is themed in a a [big plist][theme plist]. If you can't find a theme key you'd like to use, ask and we'll add it!

[posts view]: App/Posts/PostsView.swift
[default theme]: AwfulTheming/Sources/AwfulTheming/Stylesheets/posts-view.less
[YOSPOS CSS theme]: AwfulTheming/Sources/AwfulTheming/Stylesheets/posts-view-yospos.less
[FYAD CSS theme]: AwfulTheming/Sources/AwfulTheming/Stylesheets/posts-view-fyad.less
[lesscss]: https://lesscss.org/features/
[theme plist]: App/Theming/Themes.plist

### Thread Tags

[Diabolik900][] and [The Dave][] have largely fashioned Awful with its own [set of thread tags][thread tags] that look great on the iPhone and the iPad. They're distributed with the app. New thread tags can also [appear in Awful][AwfulThreadTags] without us having to send an update through the App Store. This is done by hosting the icons via [GitHub Pages][awfulapp.com.git].

To add a new thread tag you just made:

1. Add it to the [thread tags repository][Thread Tags.git] and push.
2. Update the [awfulapp.com repository][awfulapp.com.git] repository per [its README][awfulapp.com.git README].
3. In this (Awful.app) repository, update the `App/Resources/Thread Tags` submodule and push:

    ```bash
    cd path/to/awful-app/repo
    cd App/Resources/Thread\ Tags
    git pull origin master
    cd ..
    git commit -am "Updated thread tags."
    git push
    ```

[AwfulThreadTags]: App/Thread%20Tags/ThreadTagLoader.swift
[awfulapp.com.git]: https://github.com/Awful/awful.github.io
[awfulapp.com.git README]: https://github.com/Awful/awful.github.io/blob/master/README.md#thread-tags
[Thread Tags.git]: https://github.com/Awful/thread-tags

### Alternate App Icons

To add a new alternate app icon:

1. Open `App/App Icons/App Icons.xcassets`.
2. Add a new iOS App Icon.
3. Name your app icon something appropriate, including the `_appicon` suffix.
4. In the Attributes inspector, from the Appearances popover, choose "Any, Dark, Tinted" (assuming you have dark and tinted variants of your icon).
4. Drag your 1024px×1024px image file over.
5. Add a new Image Set with the same name as your icon set plus `_preview`.
6. Make and drag 120px×120px (60pt @2x) and 180px×180px (60pt @3x) icons into your preview icon set. (e.g. `sips -Z 120 cool-icon.png`.)
7. Run `Scripts/app-icons`. This will update the relevant build settings, make the image names available in Swift, and yell at you if you miss some of the above steps.
8. Open `App/Settings/SettingsViewController.swift`.
9. Add your new app icon info to the `appIcons` array.

The bookkeeping and duplicate images are unfortunate, but there's no public API to list app icon sets or to load app icon images for display. Instead of hacking together something that could break later, we'll do it ourselves.

## URL schemes

Awful answers to a couple URL schemes:

* `awful:` opens Awful directly to various screens. This URL scheme is documented at http://handleopenurl.com and at [Launch Center Pro](http://actions.contrast.co).
    * `awful://forums` opens the Forums tab.
    * `awful://forums/:forumid` opens the Forums tab to the identified forum.
    * `awful://threads/:threadid` opens the first page of the identified thread. For example, `awful://threads/3510131` opens Awful's thread.
    * `awful://threads/:threadid/pages/:page` opens the given page of the identified thread. For example, `awful://threads/3510131/pages/15` opens the fifteenth page of Awful's thread.
    * `awful://posts/:postid` opens the identified post's page of its thread and jumps to it. For example, `awful://posts/408179339` opens the OP of Awful's thread.
    * `awful://bookmarks` opens the Bookmarks tab.
    * `awful://messages` opens the Messages tab.
    * `awful://messages/:messageid` opens the identified private message. (I guess the idea is to handle a link from one message to another?)
    * `awful://settings` opens the Settings tab.
    * `awful://users/:userid` opens the identified user's profile. For example, `awful://users/106125` opens pokeyman's profile.
    * `awful://banlist` opens the Leper's Colony.
    * `awful://banlist/:userid` opens the identified user's rap sheet. For example, `awful://banlist/106125` opens pokeyman's rap sheet.
* `awfulhttp:` and `awfulhttps:` handle Forums website URLs by opening the corresponding screen when possible.
    * The idea is you take your `https://forums.somethingawful.com/…` URL, put `awful` in front, and now it opens in Awful.

## iOS deployment targets

For iOS | Check out tag/branch
------- | --------------------
17 | main
16 | main
15 | main
14 | ios-14
13 | ios-13
12 | ios-12
11 | ios-11
10 | ios-10
9  | ios-9
8  | ios-8
7  | ios-7
6  | ios-6
5  | ios-5

## License

[Creative Commons Attribution-NonCommercial-ShareAlike 3.0 United States License](http://creativecommons.org/licenses/by-nc-sa/3.0/us/)

## Credit

Awful development is led by [pokeyman][] aka [Nolan Waite](https://github.com/nolanw).

Awful includes contributions from:

- [awesomeolion](https://forums.somethingawful.com/member.php?action=getinfo&userid=127057)
- [carry on then](https://forums.somethingawful.com/member.php?action=getinfo&userid=165974)
- [CLAM DOWN](https://forums.somethingawful.com/member.php?action=getinfo&userid=110481)
- [commie kong](https://forums.somethingawful.com/member.php?action=getinfo&userid=224355)
- [Diabolik900][]
- [enigma105](http://forums.somethingawful.com/member.php?action=getinfo&userid=51258)
- [Froist](http://forums.somethingawful.com/member.php?action=getinfo&userid=56411)
- [hardstyle](http://forums.somethingawful.com/member.php?action=getinfo&userid=51070)
- [JamesOff](http://forums.somethingawful.com/member.php?action=getinfo&userid=32221)
- [Jose Valasquez](http://forums.somethingawful.com/member.php?action=getinfo&userid=77039)
- [Malcolm XML](http://forums.somethingawful.com/member.php?action=getinfo&userid=154586)
- [OHIO](http://forums.somethingawful.com/member.php?action=getinfo&userid=82915)
- [pokeyman][]
- [spanky the dolphin](https://forums.somethingawful.com/member.php?action=getinfo&userid=102668)
- [Subjunctive](http://forums.somethingawful.com/member.php?action=getinfo&userid=103253)
- [tanky](https://forums.somethingawful.com/member.php?action=getinfo&userid=161836)
- [The Dave][]
- [ultramiraculous](http://forums.somethingawful.com/member.php?action=getinfo&userid=44504)
- [xzzy](http://forums.somethingawful.com/member.php?action=getinfo&userid=148096)
- [101](https://forums.somethingawful.com/member.php?action=getinfo&userid=191441)

[Diabolik900]: http://forums.somethingawful.com/member.php?action=getinfo&userid=113215
[pokeyman]: http://forums.somethingawful.com/member.php?action=getinfo&userid=106125
[The Dave]: http://forums.somethingawful.com/member.php?action=getinfo&userid=41741
