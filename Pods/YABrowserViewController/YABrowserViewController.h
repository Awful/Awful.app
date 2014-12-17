// YABrowserViewController.h  https://github.com/nolanw/YABrowserViewController  Public Domain

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

/**
 A slimmed-down, poorer rendition of Safari. (Yet Another Browser View Controller)
 
 This one handles various annoyances with WKWebView, such as opening non-HTTP URLs and opening target=_blank links. It includes a history, visible by long-pressing the back button.
 
 If you set the browser view controller's restorationIdentifier, its title and current page's URL are preserved and restored. Unfortunately it does not seem to be possible to preserve the browser history.
 */
IB_DESIGNABLE
@interface YABrowserViewController : UIViewController <UIViewControllerRestoration, WKNavigationDelegate, WKUIDelegate>

/**
 The current page's absolute URL as a string.
 
 You may set this property before the view is loaded, in which case it will automatically start loading in -viewWillAppear:. Once the web view is loaded, URLString simply passes through to the web view's URL property.
 
 Is *not* key-value observing compliant. If you would like KVO, please observe the webView's URL property directly.
 */
@property (strong, nonatomic) IBInspectable NSString *URLString;
// (URLString is an NSString in order to be IBInspectable; Interface Builder doesn't do NSURLs.)

/**
 The browser view controller's web view. If you want to load an HTML string or a particular NSURLRequest, please call on the web view directly.
 
 The view controller acts as the web view's navigation delegate and UI delegate.
 
 If you access the property when it is currently nil, the view is automatically loaded.
 */
@property (readonly, strong, nonatomic) WKWebView *webView;

/// Conveniently wrap the browser view controller in a UINavigationController and present it, complete with a close button in the top left corner.
- (void)presentFromViewController:(UIViewController *)presentingViewController animated:(BOOL)animated completion:(void (^)(void))completion;

/// An array of UIActivity objects to add to the share sheet. Default is nil.
@property (copy, nonatomic) NSArray *applicationActivities;

@end
