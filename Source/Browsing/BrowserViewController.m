//  BrowserViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "BrowserViewController.h"
#import "AwfulExternalBrowser.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
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
    [self.webView removeObserver:self forKeyPath:@"title" context:KVOContext];
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
    _actionItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actOnCurrentPage:)];
    return _actionItem;
}

- (void)actOnCurrentPage:(UIBarButtonItem *)sender
{
    if (self.presentedViewController) return;
	NSURL *URL = self.webView.URL;
    if (URL.absoluteString.length == 0) {
        URL = self.URL;
    }
    UIAlertController *actionSheet = [UIAlertController actionSheet];
    
    [actionSheet addActionWithTitle:@"Open in Safari" handler:^{
        [[UIApplication sharedApplication] openURL:URL];
    }];
    
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:URL]) continue;
        [actionSheet addActionWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title] handler:^{
            [browser openURL:URL];
        }];
    }
    
    for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
        [actionSheet addActionWithTitle:service.callToAction handler:^{
            [service saveURL:URL];
        }];
    }
    
    [actionSheet addActionWithTitle:@"Copy URL" handler:^{
        [AwfulSettings sharedSettings].lastOfferedPasteboardURL = URL.absoluteString;
        [UIPasteboard generalPasteboard].awful_URL = URL;
    }];
    
    [actionSheet addCancelActionWithHandler:nil];
    
    [self presentViewController:actionSheet animated:YES completion:nil];
    actionSheet.popoverPresentationController.barButtonItem = sender;
}

- (UIBarButtonItem *)backItem
{
    if (_backItem) return _backItem;
    UIImage *image = [UIImage imageNamed:@"arrowleft"];
    _backItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    _backItem.accessibilityLabel = @"Back";
    return _backItem;
}

- (void)goBack
{
    [self.webView goBack];
}

- (UIBarButtonItem *)forwardItem
{
    if (_forwardItem) return _forwardItem;
    UIImage *image = [UIImage imageNamed:@"arrowright"];
    _forwardItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    _forwardItem.accessibilityLabel = @"Forward";
    return _forwardItem;
}

- (void)goForward
{
    [self.webView goForward];
}

- (void)updateBackForwardItemEnabledState
{
    if ([self isViewLoaded]) {
        self.backItem.enabled = self.webView.canGoBack;
        self.forwardItem.enabled = self.webView.canGoForward;
    } else {
        self.backItem.enabled = NO;
        self.forwardItem.enabled = NO;
    }
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
        self.navigationItem.leftBarButtonItem = item;
    }
}

- (void)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == KVOContext) {
        if ([keyPath isEqualToString:@"title"]) {
            NSString *title = change[NSKeyValueChangeNewKey];
            self.title = title.length > 0 ? title : @"Awful Browser";
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - UIWebViewDelegate

-(void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
	[self showNetworkIndicator];
	[self updateBackForwardItemEnabledState];
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{

	// We started with a clear background to avoid a FOUC, but websites expect a white background if they don't explicitly set one themselves. So now we need to set it white.
	webView.backgroundColor = [UIColor whiteColor];
	webView.opaque = YES;
	[self hideNetworkIndicator];
	_URL = self.webView.URL;
	[self preventDefaultLongTapMenu];
	[self updateBackForwardItemEnabledState];
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
