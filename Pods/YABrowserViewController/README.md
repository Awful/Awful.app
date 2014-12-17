# YABrowserViewController

Yet Another Browser View Controller.

We've all written these things a million times. Here's another one.

## When to use YABrowserViewController

You're tired of, or want a head start on, rewriting a little skin over a web view so that people don't get punted out to Safari just to open a website. And you want `WKWebView`'s power while mitigating its [deficiencies][].

[deficiencies]: https://github.com/ShingoFukuyama/WKWebViewTips#readme

## When not to use YABrowserViewController

You want third-party code to permanently mess with your navigation bars. You love undocumented Key-Value Observing usage. You'd like a bunch of other dependencies to be pulled in. You need `NSHTTPCookieStorage`, `NSURLCache`, `NSURLProtocol`, access to folders that aren't `tmp`, state-preserved URL history, or something else that `WKWebView` doesn't care for.

## System Requirements

YABrowserViewController supports iOS 8.0+.

## Installation

You have options:

1. Drag `YABrowserViewController.xcodeproj` into your project, add `YABrowserViewController` as a Target Dependency, then add `YABrowserViewController.framework` to your Embedded Binaries, then `@import YABrowserViewController;` or `import YABrowserViewController` as necessary. (This is how the included sample app is configured, if you need inspiration.)
2. Drag `YABrowserViewController.h` and `YABrowserViewController.m` into your project, along with the `Images` folder.
3. Either of the above options, but first add this repository as a submodule.
4. Using [CocoaPods][], add to your Podfile: `pod 'YABrowserViewController'`
5. Using [Carthage][], add to your Cartfile: `github "nolanw/YABrowserViewController"`

[Carthage]: https://github.com/Carthage/Carthage
[CocoaPods]: http://cocoapods.org/

## Usage

```swift
let browser = YABrowserViewController()
browser.URLString = "https://github.com/nolanw/YABrowserViewController"
browser.presentFromViewController(self, animated: true, completion: nil)
```

Customization isn't YABrowserViewController's strong suit, in that it doesn't really do very much. There aren't any knobs to dial. Instead, you can just set the view controller and navigation controller properties yourself to do whatever you like. Or copy the files over and edit them to suit your needs.

For example, there's a little convenience method there, `-presentFromViewController:animated:completion:`, for modal presentation. Not enough? Toss a category on `YABrowserViewController` and set up a `UINavigationController` however you please!

If you'd like to poke around, see the [SampleBrowser][] app. It has UIKit state preservation and restoration enabled, so you can test that out.

[SampleBrowser]: SampleBrowser

## Alternatives

No shortage of these.

* [ACWebViewController](https://github.com/achainan/WebView)
* [CrayWebViewController](https://github.com/PlusR/CrayWebViewController)
* [DZNWebViewController](https://github.com/dzenbot/DZNWebViewController)
* [EGYWebViewController](https://github.com/iMokhles/EGYWebViewController)
* [JBWebViewController](https://github.com/boserup/JBWebViewController)
* [KAWebViewController](https://github.com/adamskyle/KAWebViewController)
* [KINWebBrowser](https://github.com/dfmuir/KINWebBrowser)
* [M2DWebViewController](https://github.com/0x0c/M2DWebViewController)
* [PAMWebBrowser](https://github.com/PAM-AS/PAMWebBrowser)
* [PBWebViewController](https://github.com/kmikael/PBWebViewController)
* [STKWebKitViewController](https://github.com/sticksen/STKWebKitViewController)
* [SVWebViewController](https://github.com/TransitApp/SVWebViewController)
* [TAWebViewController](https://github.com/TosinAF/TAWebViewController)
* [THWebViewController](https://github.com/tokuhirom/THWebViewController)
* [TOWebViewController](https://github.com/TimOliver/TOWebViewController)
* [TSMiniWebBrowser](https://github.com/tonisalae/TSMiniWebBrowser)
* [WebViewController](https://github.com/mergesort/WebViewController)

## Credits

YABrowserViewController is by [Nolan Waite][].

[Nolan Waite]: https://github.com/nolanw

## License

Public domain.
