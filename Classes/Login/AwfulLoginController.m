//
//  AwfulLoginController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoginController.h"
#import "AwfulAppDelegate.h"
#import "AwfulNetworkEngine.h"
#import "AwfulSettingsViewController.h"
#import "AwfulUser.h"

@interface AwfulLoginController ()

@property (nonatomic, strong) IBOutlet UIWebView *web;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *act;

@end

@implementation AwfulLoginController

@synthesize web = _web;
@synthesize act = _act;
@synthesize accountViewController = _accountViewController;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Login?";
    
    NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com/account.php?action=loginform"];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    self.web.scalesPageToFit = YES;
    self.web.delegate = self;
    [self.web loadRequest:req];
    [self.web addSubview:self.act];
    [self.act startAnimating];
}

- (void)viewDidUnload {
    self.web = nil;
    self.act = nil;
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (IBAction)cancel
{
    [self.navigationController.presentingViewController dismissModalViewControllerAnimated:YES];
    [self.accountViewController refresh];
}

- (void)didLogIn
{
    [self.navigationController.presentingViewController dismissModalViewControllerAnimated:YES];
    [self.accountViewController refresh];
    [ApplicationDelegate.awfulNetworkEngine forumsListOnCompletion:nil onError:nil];
}

#pragma mark Web View delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSURLRequest *req = webView.request;
    if ([[req.URL relativePath] isEqualToString:@"/index.php"]) {
        self.web.delegate = nil;
        [self didLogIn];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.act stopAnimating];
}

@end

BOOL IsLoggedIn()
{
    NSURL *awful_url = [NSURL URLWithString:@"http://forums.somethingawful.com"];
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:awful_url];
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.name isEqualToString:@"bbuserid"]) {
            return YES;
        }
    }
    return NO;
}
