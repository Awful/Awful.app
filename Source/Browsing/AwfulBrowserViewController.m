//  AwfulBrowserViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBrowserViewController.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import "AwfulActionSheet.h"
#import "AwfulExternalBrowser.h"
#import "AwfulPageBarBackgroundView.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"
#import "AwfulUIKitAndFoundationCategories.h"

@interface AwfulBrowserViewController () <UIWebViewDelegate>

@property (readonly, strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) UIBarButtonItem *actionItem;
@property (strong, nonatomic) UIBarButtonItem *backItem;
@property (strong, nonatomic) UIBarButtonItem *forwardItem;
@property (assign, nonatomic) BOOL loading;

@end

@implementation AwfulBrowserViewController

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
        self.toolbarItems = @[ self.backItem, self.forwardItem, [UIBarButtonItem flexibleSpace], self.actionItem ];
    }
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
    NSURL *url = self.webView.request.URL;
    if (url.absoluteString.length == 0) {
        url = self.URL;
    }
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    [sheet addButtonWithTitle:@"Open in Safari" block:^{
        [[UIApplication sharedApplication] openURL:url];
    }];
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:url]) continue;
        [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                            block:^{ [browser openURL:url]; }];
    }
    for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
        [sheet addButtonWithTitle:service.callToAction block:^{
            [service saveURL:url];
        }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        NSURL *url = self.webView.request.URL;
        [AwfulSettings settings].lastOfferedPasteboardURL = [url absoluteString];
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: url,
            (id)kUTTypePlainText: [url absoluteString]
        } ];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
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
        [self.navigationItem.titleView setNeedsLayout];
    }
}

- (void)loadView
{
    UIWebView *webView = [UIWebView new];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    webView.scalesPageToFit = YES;
    
    // Start with a clear background for the web view to avoid a FOUC.
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;
    
    self.view = webView;
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.view.backgroundColor = self.theme[@"browserBackgroundColor"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.presentingViewController) {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(dismiss)];
        self.navigationItem.leftBarButtonItem = item;
    }
}

- (void)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (self.URL) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.URL]];
    }
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

@end
