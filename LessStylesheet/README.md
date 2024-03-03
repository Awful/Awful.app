# LessStylesheet

A build tool plugin for turning `.less` into `.css`.

There's no convenient way to pass configuration options to a build tool plugin, so this build tool plugin distinguishes between:

* "Importable" `.less` files, which have a leading underscore (e.g. `_base.less`) and do not have any corresponding `.css` output file.
* Each other `.less` file results in a `.css` output file.

Leave off the underscore when importing, e.g. in your `.less` file do `@import "base.less"` to import `_base.less`.

Each output `.css` file depends (in the build system sense) on all importable `.less` files in addition to its main `.less` file. Doing something smarter doesn't seem worth the effort right now.

## lessc

A wrapper around the browser rendition of `less.js`, executed via JavaScriptCore, and called by the build tool plugin.

We use the browser rendition as it doesn't require (heh) any module system to run.

Update `less.js` via e.g. https://github.com/less/less.js/raw/v4.2.0/dist/less.js (changing the version as desired, look at https://github.com/less/less.js/releases for suggestions). There's no expected upside to using a minified copy so grab the readable one.

## Working around Xcode's inability to make an archive when a build tool plugin depends on an executable from the same package

When doing an archive, Xcode (and xcodebuild) don't build `lessc` and so the build fails trying to run the generated build commands. To work around this, a prebuilt copy of `lessc` lives in the `Prebuilt` directory. To update:

```sh
cd LessStylesheet/
swift build --product lessc --configuration release --arch arm64 --arch x86_64
cp -R .build/apple/Products/Release/lessc .build/apple/Products/Release/*.bundle Prebuilt/
```
