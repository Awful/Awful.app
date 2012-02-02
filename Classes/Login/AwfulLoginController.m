//
//  AwfulLoginController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoginController.h"
#import "AwfulAppDelegate.h"
#import "AwfulNavigator.h"
#import "AwfulUser.h"

@implementation AwfulLoginController

@synthesize web = _web;
@synthesize act = _act;

-(id)init 
{
    if((self=[super initWithNibName:@"AwfulLoginController" bundle:[NSBundle mainBundle]])) {
        
    }
    return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Login?";
    
    NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com/account.php?action=loginform"];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    self.web.scalesPageToFit = YES;
    self.web.delegate = self;
    [self.web loadRequest:req];
    
    self.act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.act.center = CGPointMake(160, 100);
    [self.act startAnimating];
    [self.web addSubview:self.act];
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
        [self.navigationController popViewControllerAnimated:YES];
        AwfulNavigator *nav = getNavigator();
        [nav.user loadUser];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.act removeFromSuperview];
    [self.act stopAnimating];
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
