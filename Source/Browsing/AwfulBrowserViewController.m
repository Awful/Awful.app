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

@property (nonatomic) UIBarButtonItem *actionButton;
@property (nonatomic) UIBarButtonItem *backBrowserButton;
@property (nonatomic) UIBarButtonItem *forwardBrowserButton;
@property (weak, nonatomic) UISegmentedControl *backForwardControl;

@property (weak, nonatomic) UIToolbar *toolbar;

@end

@implementation AwfulBrowserViewController

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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet showFromBarButtonItem:self.actionButton animated:YES];
    } else {
        [sheet showFromToolbar:self.toolbar];
    }
}

- (void)actOnCurrentPage:(UISegmentedControl *)seg
{
    [self actOnCurrentPage];
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)backOrForwardTapped:(UISegmentedControl *)seg
{
    if (seg.selectedSegmentIndex == 0) {
        [self.webView goBack];
    } else {
        [self.webView goForward];
    }
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
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
    button.accessibilityLabel = @"Act";
    _actionButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    return _actionButton;
}

- (UIBarButtonItem *)backBrowserButton
{
    if (_backBrowserButton) return _backBrowserButton;
    UIButton *button = MakeBorderlessButton([UIImage imageNamed:@"arrowleft.png"],
                                            self, @selector(browserBack));
    button.accessibilityLabel = @"Browser-back";
    _backBrowserButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    return _backBrowserButton;
}

- (UIBarButtonItem *)forwardBrowserButton
{
    if (_forwardBrowserButton) return _forwardBrowserButton;
    UIButton *button = MakeBorderlessButton([UIImage imageNamed:@"arrowright.png"],
                                            self, @selector(browserForward));
    button.accessibilityLabel = @"Browser-forward";
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
    [self.backForwardControl setEnabled:[self.webView canGoBack] forSegmentAtIndex:0];
    self.forwardBrowserButton.enabled = [self.webView canGoForward];
    [self.backForwardControl setEnabled:[self.webView canGoForward] forSegmentAtIndex:1];
}

- (void)retheme:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    self.view.backgroundColor = [AwfulTheme currentTheme].postsViewBackgroundColor;
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(retheme:)
                                                 name:AwfulThemeDidChangeNotification object:nil];
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
        CGRectDivide(webViewFrame, &toolbarFrame, &webViewFrame, 38, CGRectMaxYEdge);
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];
        toolbar.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleTopMargin);
        toolbar.barStyle = UIBarStyleBlack;
        UIImage *background = [[UIImage imageNamed:@"pagebar.png"]
                               resizableImageWithCapInsets:UIEdgeInsetsZero];
        [toolbar setBackgroundImage:background
                 forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
        UIImage *back = [UIImage imageNamed:@"arrowleft.png"];
        back.accessibilityLabel = @"Browser-back";
        UIImage *forward = [UIImage imageNamed:@"arrowright.png"];
        forward.accessibilityLabel = @"Browser-forward";
        UISegmentedControl *backForwardControl = MakeSegmentedBarButton(@[ back, forward ]);
        [backForwardControl addTarget:self action:@selector(backOrForwardTapped:)
                     forControlEvents:UIControlEventValueChanged];
        UIBarButtonItem *backForward = [[UIBarButtonItem alloc] initWithCustomView:backForwardControl];
        self.backForwardControl = backForwardControl;
        UIBarButtonItem *space;
        space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                              target:nil action:NULL];
        UIImage *action = [UIImage imageNamed:@"action.png"];
        action.accessibilityLabel = @"Act";
        UISegmentedControl *actionControl = MakeSegmentedBarButton(@[ action ]);
        [actionControl addTarget:self action:@selector(actOnCurrentPage:)
                forControlEvents:UIControlEventValueChanged];
        UIBarButtonItem *actionItem = [[UIBarButtonItem alloc] initWithCustomView:actionControl];
        toolbar.items = @[ backForward, space, actionItem ];
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

static UISegmentedControl * MakeSegmentedBarButton(NSArray *items)
{
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.frame = CGRectMake(0, 0, [items count] == 1 ? 40 : 85, 29);
    UIImage *back = [[UIImage imageNamed:@"pagebar-button.png"]
                     resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    [seg setBackgroundImage:back forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    UIImage *selected = [[UIImage imageNamed:@"pagebar-button-selected.png"]
                         resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    [seg setBackgroundImage:selected forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    [seg setDividerImage:[UIImage imageNamed:@"pagebar-segmented-divider.png"]
     forLeftSegmentState:UIControlStateNormal
       rightSegmentState:UIControlStateNormal
              barMetrics:UIBarMetricsDefault];
    return seg;
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
    [self retheme:nil];
}

- (void)dealloc
{
    self.webView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateBackForwardButtonEnabledState];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    webView.backgroundColor = [UIColor whiteColor];
    webView.opaque = YES;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    _URL = webView.request.URL;
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    [self preventDefaultLongTapMenu];
    [self updateBackForwardButtonEnabledState];
}

@end
