//
//  AwfulLicensesViewController.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLicensesViewController.h"
#import "AwfulTheme.h"

@interface AwfulLicensesViewController () <UIWebViewDelegate> @end

@implementation AwfulLicensesViewController

- (id)init
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.title = @"Licenses";
    return self;
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self init];
}

- (void)loadView
{
    UIWebView *webView = [UIWebView new];
    webView.delegate = self;
    NSURL *licenses = [[NSBundle mainBundle] URLForResource:@"licenses" withExtension:@"html"];
    [webView loadRequest:[NSURLRequest requestWithURL:licenses]];
    self.view = webView;
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSString *js = [NSString stringWithFormat:
                    @"document.body.style.color = '%@';"
                     "document.body.style.backgroundColor = '%@';"
                     "var as = document.getElementsByTagName('a');"
                     "for (var i = 0; i < as.length; i++) as[i].style.color = '%@'",
                    [AwfulTheme currentTheme].licensesViewTextHTMLColor,
                    [AwfulTheme currentTheme].licensesViewBackgroundHTMLColor,
                    [AwfulTheme currentTheme].licensesViewLinkHTMLColor];
    [webView stringByEvaluatingJavaScriptFromString:js];
}

@end
