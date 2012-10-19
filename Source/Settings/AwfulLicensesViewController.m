//
//  AwfulLicensesViewController.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLicensesViewController.h"

@implementation AwfulLicensesViewController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Licenses";
    }
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
    NSURL *licenses = [[NSBundle mainBundle] URLForResource:@"licenses" withExtension:@"html"];
    [webView loadRequest:[NSURLRequest requestWithURL:licenses]];
    self.view = webView;
}

@end
