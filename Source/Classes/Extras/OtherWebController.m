//
//  OtherWebController.m
//  Awful
//
//  Created by Sean Berry on 9/12/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "OtherWebController.h"
#import "AwfulAppDelegate.h"
#import "AwfulSettings.h"

@implementation OtherWebController

@synthesize url, activity, web, backButton, forwardButton, openedApp;

-(id)initWithURL : (NSURL *)aUrl
{
    if((self=[super initWithNibName:nil bundle:nil])) {
        self.url = aUrl;
        self.openedApp = NO;
        self.web = nil;
    }
    return self;
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
    self.web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 420)];
    self.web.scalesPageToFit = YES;
    self.web.delegate = self;
    
    [self.web loadRequest:[NSURLRequest requestWithURL:self.url]];
    
    self.view = self.web;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)loadToolbar
{
    self.backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_arrow_left.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    self.forwardButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_arrow_right.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshPage)];
    UIBarButtonItem *safari = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(openInSafari)];
    
    UIBarButtonItem *fixed = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixed.width = 20;
    
    UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activity = [[UIBarButtonItem alloc] initWithCustomView:act];

    NSArray *items = [NSArray arrayWithObjects:self.backButton, fixed, self.forwardButton, flex, activity, fixed, refresh, fixed, safari, nil];
    [self setToolbarItems:items];
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if([[request.URL host] isEqualToString:@"itunes.apple.com"] || [[request.URL host] isEqualToString:@"phobos.apple.com"]) {
        if(!self.openedApp) {
            self.openedApp = YES;
            [[UIApplication sharedApplication] openURL:request.URL];
            return YES;
        }
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    self.backButton.enabled = [webView canGoBack];
    self.forwardButton.enabled = [webView canGoForward];
    self.web = webView;
    
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    UIActivityIndicatorView *act = (UIActivityIndicatorView *)activity.customView;
    [act startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    UIActivityIndicatorView *act = (UIActivityIndicatorView *)self.activity.customView;
    [act stopAnimating];
}

-(void)goBack
{
    [self.web goBack];
}

-(void)goForward
{
    [self.web goForward];
}

-(void)refreshPage
{
    [self.web reload];
}

-(void)openInSafari
{
    [[UIApplication sharedApplication] openURL:self.web.request.URL];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

-(void)hitDone
{
    [self.navigationController dismissModalViewControllerAnimated:YES];
}

-(void)viewDidLoad
{
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(hitDone)];
    self.navigationItem.leftBarButtonItem = done;
    
    [self loadToolbar];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


@end
