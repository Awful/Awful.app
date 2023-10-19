# Awful manually-installed dependencies

## Sources and explanations

* [ARChromeActivity](https://github.com/alextrob/ARChromeActivity) is included here for its icons, which can't yet be distributed via SPM.
* [PullToRefresh](https://github.com/Yalantis/PullToRefresh) was the last thing we used CocoaPods for, so we made a lil `Package.swift` for it. Version 3.3 breaks something so we're stuck on 3.2. If we need to do something about 3.2 we should probably find some other library (or write our own).
* [Sourcery](https://github.com/krzysztofzablocki/Sourcery/releases) is downloaded and copied over manually, with seemingly irrelevant bits deleted.
* [TUSafariActivity](https://github.com/davbeck/TUSafariActivity) is included here for its icons and localized strings, which can't yet be distributed via SPM.
