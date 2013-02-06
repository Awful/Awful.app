//
//  AwfulBrowserViewController.m
//  Awful
//
//  Created by Nolan Waite on 2012-12-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBrowserViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulExternalBrowser.h"
#import "AwfulTheme.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulBrowserViewController () <UIWebViewDelegate>

@property (weak, nonatomic) UIWebView *webView;

@property (readonly, nonatomic) UIBarButtonItem *actionButton;

@property (readonly, nonatomic) UIBarButtonItem *backBrowserButton;

@property (readonly, nonatomic) UIBarButtonItem *forwardBrowserButton;

@property (weak, nonatomic) UIToolbar *toolbar;

@end

@implementation AwfulBrowserViewController
{
    UIBarButtonItem *_actionButton;
    UIBarButtonItem *_backBrowserButton;
    UIBarButtonItem *_forwardBrowserButton;
}

- (void)actOnCurrentPage
{
    NSURL *url = self.webView.request.URL;
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    [sheet addButtonWithTitle:@"Open in Safari" block:^{
        [[UIApplication sharedApplication] openURL:url];
    }];
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:url]) continue;
        [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                            block:^{ [browser openURL:url]; }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: self.webView.request.URL,
            (id)kUTTypePlainText: [self.webView.request.URL absoluteString]
        } ];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromBarButtonItem:self.actionButton animated:YES];
}

- (void)browserBack
{
    [self.webView goBack];
}

- (void)browserForward
{
    [self.webView goForward];
}

- (void)setURL:(NSURL *)URL
{
    if (_URL == URL) return;
    _URL = URL;
    [self.webView loadRequest:[NSURLRequest requestWithURL:URL]];
}

- (void)preventDefaultLongTapMenu
{
    [self.webView stringByEvaluatingJavaScriptFromString:
     @"document.body.style.webkitTouchCallout='none'"];
}

- (UIBarButtonItem *)actionButton
{
    if (_actionButton) return _actionButton;
    UIButton *button = MakeBorderlessButton([UIImage imageNamed:@"action.png"],
                                            self, @selector(actOnCurrentPage));
    button.accessibilityLabel = @"Action";
    _actionButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    return _actionButton;
}

- (UIBarButtonItem *)backBrowserButton
{
    if (_backBrowserButton) return _backBrowserButton;
    UIButton *button = MakeBorderlessButton([UIImage imageNamed:@"arrowleft.png"],
                                            self, @selector(browserBack));
    button.accessibilityLabel = @"Back";
    button.accessibilityHint = @"Go to previous page";
    _backBrowserButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    return _backBrowserButton;
}

- (UIBarButtonItem *)forwardBrowserButton
{
    if (_forwardBrowserButton) return _forwardBrowserButton;
    UIButton *button = MakeBorderlessButton([UIImage imageNamed:@"arrowright.png"],
                                            self, @selector(browserForward));
    button.accessibilityLabel = @"Forward";
    button.accessibilityHint = @"Go to next page";
    _forwardBrowserButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    return _forwardBrowserButton;
}

static UIButton * MakeBorderlessButton(UIImage *image, id target, SEL action)
{
    UIButton *button = [UIButton new];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [button setImage:image forState:UIControlStateNormal];
    button.showsTouchWhenHighlighted = YES;
    [button sizeToFit];
    CGRect frame = button.frame;
    frame.size.width = 44;
    button.frame = frame;
    return button;
}

- (void)updateBackForwardButtonEnabledState
{
    self.backBrowserButton.enabled = [self.webView canGoBack];
    self.forwardBrowserButton.enabled = [self.webView canGoForward];
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.title = @"Awful Browser";
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.navigationItem.rightBarButtonItems = @[
            self.actionButton, self.forwardBrowserButton, self.backBrowserButton
        ];
    }
    self.forwardBrowserButton.enabled = self.backBrowserButton.enabled = NO;
    return self;
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
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    CGRect webViewFrame = (CGRect){ .size = self.view.frame.size };
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        CGRect toolbarFrame;
        CGRectDivide(webViewFrame, &toolbarFrame, &webViewFrame, 44, CGRectMaxYEdge);
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];
        toolbar.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleTopMargin);
        toolbar.barStyle = UIBarStyleBlack;
        UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                               target:nil action:NULL];
        toolbar.items = @[
            self.backBrowserButton, self.forwardBrowserButton, space, self.actionButton
        ];
        [self.view addSubview:toolbar];
        self.toolbar = toolbar;
    }
    UIWebView *webView = [[UIWebView alloc] initWithFrame:webViewFrame];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    webView.scalesPageToFit = YES;
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;
    [self.view addSubview:webView];
    self.webView = webView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (self.URL) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.URL]];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.webView.backgroundColor = [AwfulTheme currentTheme].postsViewBackgroundColor;
}

- (void)dealloc
{
    self.webView.delegate = nil;
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateBackForwardButtonEnabledState];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    _URL = webView.request.URL;
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    [self preventDefaultLongTapMenu];
    [self updateBackForwardButtonEnabledState];
}

@end
