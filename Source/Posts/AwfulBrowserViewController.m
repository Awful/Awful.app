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

@property (readonly, nonatomic) UIWebView *webView;

@end

@implementation AwfulBrowserViewController

- (void)act:(UIBarButtonItem *)sender
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
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromBarButtonItem:sender animated:YES];
}

- (void)close
{
    [self.delegate browserDidClose:self];
}

- (void)setURL:(NSURL *)URL
{
    if (_URL == URL) return;
    _URL = URL;
    [self.webView loadRequest:[NSURLRequest requestWithURL:URL]];
}

- (UIWebView *)webView
{
    return (UIWebView *)self.view;
}

- (void)preventDefaultLongTapMenu
{
    [self.webView stringByEvaluatingJavaScriptFromString:
     @"document.body.style.webkitTouchCallout='none'"];
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    UIBarButtonItem *doneButton;
    doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                               target:self
                                                               action:@selector(close)];
    self.navigationItem.leftBarButtonItem = doneButton;
    UIBarButtonItem *actionButton;
    actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                 target:self
                                                                 action:@selector(act:)];
    self.navigationItem.rightBarButtonItem = actionButton;
    return self;
}

- (void)loadView
{
    self.view = [[UIWebView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.opaque = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.webView.backgroundColor = [AwfulTheme currentTheme].postsViewBackgroundColor;
}

- (void)dealloc
{
    if ([self isViewLoaded]) self.webView.delegate = nil;
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    _URL = webView.request.URL;
    NSString *title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.navigationItem.titleLabel.text = title;
    [self preventDefaultLongTapMenu];
}

@end
