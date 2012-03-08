//
//  AwfulLoginController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoginController.h"
#import "AwfulAppDelegate.h"
#import "AwfulUser.h"

@implementation AwfulLoginController

@synthesize web = _web;
@synthesize act = _act;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Login?";
    
    NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com/account.php?action=loginform"];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    self.web.scalesPageToFit = YES;
    self.web.delegate = self;
    [self.web loadRequest:req];
    [self.act startAnimating];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.web = nil;
    self.act = nil;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark Web View delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSURLRequest *req = webView.request;
    if([[req.URL relativePath] isEqualToString:@"/index.php"]) {
        self.web.delegate = nil;
        [self hitCancel:nil];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.act stopAnimating];
}

-(IBAction)hitCancel : (id)sender
{
    [self.navigationController.presentingViewController dismissModalViewControllerAnimated:YES];
}

@end

BOOL isLoggedIn()
{
    NSURL *awful_url = [NSURL URLWithString:@"http://forums.somethingawful.com"];
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:awful_url];
    
    BOOL logged_in = NO;
    
    for(NSHTTPCookie *cookie in cookies) {
        if([cookie.name isEqualToString:@"bbuserid"]) {
            logged_in = YES;
        }
    }
    return logged_in;
}
