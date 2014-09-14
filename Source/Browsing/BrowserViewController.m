//  BrowserViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "BrowserViewController.h"
#import "AwfulFrameworkCategories.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import <ARChromeActivity/ARChromeActivity.h>
#import <TUSafariActivity/TUSafariActivity.h>
@import WebKit;
#import "Awful-Swift.h"

@interface BrowserViewController () <UIViewControllerRestoration, WKNavigationDelegate, WKUIDelegate>

@property (readonly, strong, nonatomic) WKWebView *webView;
@property (strong, nonatomic) UIBarButtonItem *actionItem;
@property (strong, nonatomic) UIBarButtonItem *backItem;
@property (strong, nonatomic) UIBarButtonItem *forwardItem;
@property (assign, nonatomic) BOOL loading;

@end

@implementation BrowserViewController

- (void)dealloc
{
    [self hideNetworkIndicator];
    if ([self isViewLoaded]) {
        [self.webView removeObserver:self forKeyPath:@"title" context:KVOContext];
        [self.webView removeObserver:self forKeyPath:@"loading" context:KVOContext];
    }
}

- (id)initWithURL:(NSURL *)URL
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _URL = URL;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.title = @"Awful Browser";
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.navigationItem.rightBarButtonItems = @[ self.actionItem, self.forwardItem, self.backItem ];
            self.hidesBottomBarWhenPushed = YES;
        } else {
            self.toolbarItems = @[ self.backItem, self.forwardItem, [UIBarButtonItem awful_flexibleSpace], self.actionItem ];
        }
        
        self.restorationClass = self.class;
        [self updateBackForwardItemEnabledState];
    }
    return self;
}

- (void)setURL:(NSURL *)URL
{
    if (_URL == URL) return;
    _URL = URL;
    if ([self isViewLoaded]) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:URL]];
    }
}

+ (instancetype)presentBrowserForURL:(NSURL *)URL fromViewController:(UIViewController *)presentingViewController
{
    BrowserViewController *browser = [[self alloc] initWithURL:URL];
    browser.restorationIdentifier = [NSString stringWithFormat:@"Awful Browser for %@", presentingViewController.title];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || !presentingViewController.navigationController) {
        [presentingViewController presentViewController:[browser enclosingNavigationController] animated:YES completion:nil];
    } else {
        [presentingViewController.navigationController pushViewController:browser animated:YES];
    }
    return browser;
}

- (WKWebView *)webView
{
    return (WKWebView *)self.view;
}

- (UIBarButtonItem *)actionItem
{
    if (_actionItem) return _actionItem;
    _actionItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:nil action:nil];
    __weak __typeof__(self) weakSelf = self;
    [_actionItem awful_setActionBlock:^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        TUSafariActivity *safariActivity = [TUSafariActivity new];
        ARChromeActivity *chromeActivity = [ARChromeActivity new];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[self.URL]
                                                                                             applicationActivities:@[safariActivity, chromeActivity]];
        activityViewController.popoverPresentationController.barButtonItem = sender;
        [self presentViewController:activityViewController animated:YES completion:nil];
    }];
    return _actionItem;
}

- (UIBarButtonItem *)backItem
{
    if (_backItem) return _backItem;
    _backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowleft"] style:UIBarButtonItemStylePlain target:nil action:nil];
    _backItem.accessibilityLabel = @"Back";
    __weak __typeof__(self) weakSelf = self;
    [_backItem awful_setActionBlock:^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        [self.webView goBack];
    }];
    return _backItem;
}

- (UIBarButtonItem *)forwardItem
{
    if (_forwardItem) return _forwardItem;
    _forwardItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowright"] style:UIBarButtonItemStylePlain target:nil action:nil];
    _forwardItem.accessibilityLabel = @"Forward";
    __weak __typeof__(self) weakSelf = self;
    [_forwardItem awful_setActionBlock:^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        [self.webView goForward];
    }];
    return _forwardItem;
}

- (void)updateBackForwardItemEnabledState
{
    self.backItem.enabled = [self isViewLoaded] && self.webView.canGoBack;
    self.forwardItem.enabled = [self isViewLoaded] && self.webView.canGoForward;
}

- (void)preventDefaultLongTapMenu
{
	[self.webView evaluateJavaScript:@"document.body.style.webkitTouchCallout='none'" completionHandler:nil];
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.titleLabel.text = title;
    }
}

- (void)loadView
{
    WKWebView *webView = [WKWebView new];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.navigationDelegate = self;
	webView.UIDelegate = self;
    webView.restorationIdentifier = @"Awful Browser web view";
    
    // Start with a clear background for the web view to avoid a FOUC.
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;
    
    [webView addObserver:self forKeyPath:@"title" options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew) context:KVOContext];
    [webView addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:KVOContext];
    
    self.view = webView;
}

static void * KVOContext = &KVOContext;

- (void)themeDidChange
{
    [super themeDidChange];
    self.view.backgroundColor = self.theme[@"browserBackgroundColor"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.URL) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.URL]];
    }
    
    if (self.presentingViewController && self.navigationController.viewControllers.count == 1) {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(dismiss)];
        __weak __typeof__(self) weakSelf = self;
        [item awful_setActionBlock:^(UIBarButtonItem *sender) {
            __typeof__(self) self = weakSelf;
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
        self.navigationItem.leftBarButtonItem = item;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == KVOContext) {
        if ([keyPath isEqualToString:@"title"]) {
            NSString *title = change[NSKeyValueChangeNewKey];
            self.title = title.length > 0 ? title : @"Awful Browser";
        } else if ([keyPath isEqualToString:@"loading"]) {
            if ([change[NSKeyValueChangeNewKey] boolValue]) {
                [self showNetworkIndicator];
            } else {
                [self hideNetworkIndicator];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)showNetworkIndicator
{
    if (!self.loading) {
        [AFNetworkActivityIndicatorManager.sharedManager incrementActivityCount];
        self.loading = YES;
    }
}

- (void)hideNetworkIndicator
{
    if (self.loading) {
        [AFNetworkActivityIndicatorManager.sharedManager decrementActivityCount];
        self.loading = NO;
    }
}

#pragma mark - UIWebViewDelegate

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
	[self updateBackForwardItemEnabledState];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
	// We started with a clear background to avoid a FOUC, but websites expect a white background if they don't explicitly set one themselves. So now we need to set it white.
	webView.backgroundColor = [UIColor whiteColor];
	webView.opaque = YES;
	_URL = self.webView.URL;
	[self preventDefaultLongTapMenu];
	[self updateBackForwardItemEnabledState];
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    NSURL *URL = [coder decodeObjectForKey:URLKey];
    BrowserViewController *viewController = [[self alloc] initWithURL:URL];
    viewController.restorationIdentifier = identifierComponents.lastObject;
    return viewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.URL forKey:URLKey];
}

static NSString * const URLKey = @"Awful Browser URL";

@end
