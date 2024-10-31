# Awful manually-installed dependencies

## Sources and explanations

* [ARChromeActivity](https://github.com/alextrob/ARChromeActivity) is included here for its icons, which can't yet be distributed via SPM.
* [lottie-player.js](https://github.com/LottieFiles/lottie-player/commit/877d251e6430fc2065e6c19a1cc232a98b202c5f) is included for Lottie animations in web views.
    * A hacked version has been released on its recommended CDN in the past (2024-10), so we ship a copy that we build ourselves.
    * Tags do not seem to be updated in the repo, so if you want to update lottie-player.js, check commits and fine a sensible one.
    * Local build steps:
        * Install node and pnpm.
        * In `package.json`, edit the dependency on `@lottiefiles/eslint-plugin@^2.2.0` to point to version 3.0.0.
        * In `package.json`, add the following to `devDependencies`:
          ```
          "@babel/plugin-proposal-private-property-in-object": "^7.21.11",
          "@babel/plugin-transform-private-methods": "^7.25.9",
          ```
        * In `babel.config.js`, find `@babel/plugin-proposal-private-methods` and replace it with `@babel/plugin-transform-private-methods`.
        * Comment out the first line of `.npmrc`.
        * `pnpm run build-lottie`
        * Grab `dist/lottie-player.js`.
* [PullToRefresh](https://github.com/Yalantis/PullToRefresh) was the last thing we used CocoaPods for, so we made a lil `Package.swift` for it. Version 3.3 breaks something so we're stuck on 3.2. If we need to do something about 3.2 we should probably find some other library (or write our own).
* [Sourcery](https://github.com/krzysztofzablocki/Sourcery/releases) is downloaded and copied over manually, with seemingly irrelevant bits deleted.
* [TUSafariActivity](https://github.com/davbeck/TUSafariActivity) is included here for its icons and localized strings, which can't yet be distributed via SPM.
