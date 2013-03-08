//
//  AwfulLicensesViewController.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLicensesViewController.h"
#import "AwfulTheme.h"
#import "AwfulThemingViewController.h"

@interface AwfulLicensesViewController () <UIWebViewDelegate, AwfulThemingViewController>

@property (weak, nonatomic) UIWebView *webView;

@end


@implementation AwfulLicensesViewController

#pragma mark - AwfulThemingViewController

- (void)retheme
{
    self.view.backgroundColor = [AwfulTheme currentTheme].licensesViewBackgroundColor;
    NSString *js = [NSString stringWithFormat:
                    @"document.body.style.color = '%@';"
                    "var as = document.getElementsByTagName('a');"
                    "for (var i = 0; i < as.length; i++) as[i].style.color = '%@'",
                    [AwfulTheme currentTheme].licensesViewTextHTMLColor,
                    [AwfulTheme currentTheme].licensesViewLinkHTMLColor];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.title = @"Licenses";
    return self;
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    UIWebView *webView = [[UIWebView alloc] initWithFrame:
                          (CGRect){ .size = self.view.bounds.size }];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;
    webView.delegate = self;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    NSURL *licenses = [[NSBundle mainBundle] URLForResource:@"licenses" withExtension:@"html"];
    [webView loadRequest:[NSURLRequest requestWithURL:licenses]];
    [self.view addSubview:webView];
    self.webView = webView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self retheme];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(retheme:)
                                                 name:AwfulThemeDidChangeNotification
                                               object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulThemeDidChangeNotification
                                                  object:nil];
    [super viewDidDisappear:animated];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self retheme];
}

@end
