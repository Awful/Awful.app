//  AwfulBrowserViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBrowserViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulExternalBrowser.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulPageBarBackgroundView.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>

@interface AwfulBrowserViewController () <UIWebViewDelegate, UIViewControllerRestoration>

@property (readonly, strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) UIBarButtonItem *actionItem;
@property (strong, nonatomic) UIBarButtonItem *backItem;
@property (strong, nonatomic) UIBarButtonItem *forwardItem;
@property (assign, nonatomic) BOOL loading;

@end

@implementation AwfulBrowserViewController
{
    AwfulActionSheet *_visibleActionSheet;
    BOOL _restoringState;
}

- (void)dealloc
{
    if ([self isViewLoaded]) {
        self.webView.delegate = nil;
    }
    [self hideNetworkIndicator];
}

- (id)initWithURL:(NSURL *)URL
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    
    self.URL = URL;
    self.title = @"Awful Browser";
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationItem.rightBarButtonItems = @[ self.actionItem, self.forwardItem, self.backItem ];
        self.hidesBottomBarWhenPushed = YES;
    } else {
        self.toolbarItems = @[ self.backItem, self.forwardItem, [UIBarButtonItem awful_flexibleSpace], self.actionItem ];
    }
    self.restorationClass = self.class;
    [self updateBackForwardItemEnabledState];
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithURL:nil];
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
    AwfulBrowserViewController *browser = [[self alloc] initWithURL:URL];
    browser.restorationIdentifier = [NSString stringWithFormat:@"Awful Browser for %@", presentingViewController.title];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || !presentingViewController.navigationController) {
        [presentingViewController presentViewController:[browser enclosingNavigationController] animated:YES completion:nil];
    } else {
        [presentingViewController.navigationController pushViewController:browser animated:YES];
    }
    return browser;
}

- (UIWebView *)webView
{
    return (UIWebView *)self.view;
}

- (UIBarButtonItem *)actionItem
{
    if (_actionItem) return _actionItem;
    _actionItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actOnCurrentPage:)];
    return _actionItem;
}

- (void)actOnCurrentPage:(UIBarButtonItem *)sender
{
    if (_visibleActionSheet) return;
    NSURL *URL = self.webView.request.URL;
    if (URL.absoluteString.length == 0) {
        URL = self.URL;
    }
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    [sheet addButtonWithTitle:@"Open in Safari" block:^{
        [[UIApplication sharedApplication] openURL:URL];
    }];
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:URL]) continue;
        [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                            block:^{ [browser openURL:URL]; }];
    }
    for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
        [sheet addButtonWithTitle:service.callToAction block:^{
            [service saveURL:URL];
        }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        [AwfulSettings sharedSettings].lastOfferedPasteboardURL = URL.absoluteString;
        [UIPasteboard generalPasteboard].awful_URL = URL;
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    _visibleActionSheet = sheet;
    [sheet setCompletionBlock:^{
        _visibleActionSheet = nil;
    }];
    [sheet showFromBarButtonItem:sender animated:YES];
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
    [self.webView stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none'"];
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
    UIWebView *webView = [UIWebView new];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    webView.scalesPageToFit = YES;
    webView.restorationIdentifier = @"Awful Browser web view";
    
    // Start with a clear background for the web view to avoid a FOUC.
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;
    
    self.view = webView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (self.URL && !_restoringState) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.URL]];
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.view.backgroundColor = self.theme[@"browserBackgroundColor"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // State restoration isn't 100% automatic for UIWebView.
    if (_restoringState) {
        [self.webView reload];
        _restoringState = NO;
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

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // We're seeing crashes in the WebThread in `-[_WebSafeForwarder forwardInvocation:]`, and calling -[UIWebView stopLoading] is a commonly-cited fix (along with nilling out the delegate, which we do up in -dealloc). Feels a bit cargo culty, but since I can't think of any ill effects from an unnecessary call to -stopLoading, here we go.
    [self.webView stopLoading];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self showNetworkIndicator];
    [self updateBackForwardItemEnabledState];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    // We started with a clear background to avoid a FOUC, but websites expect a white background if they don't explicitly set one themselves. So now we need to set it white.
    webView.backgroundColor = [UIColor whiteColor];
    webView.opaque = YES;
    [self hideNetworkIndicator];
    _URL = webView.request.URL;
    NSString *title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.title = title.length > 0 ? title : @"Awful Browser";
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
    AwfulBrowserViewController *viewController = [[self alloc] initWithURL:URL];
    viewController.restorationIdentifier = identifierComponents.lastObject;
    return viewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.URL forKey:URLKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    _restoringState = YES;
}

static NSString * const URLKey = @"Awful Browser URL";

@end
