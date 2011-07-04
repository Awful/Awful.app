    //
//  OtherWebController.m
//  Awful
//
//  Created by Sean Berry on 9/12/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "OtherWebController.h"
#import "AwfulAppDelegate.h"
#import "AwfulConfig.h"

@implementation OtherWebController

@synthesize url;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

-(id)initWithURL : (NSURL *)in_url
{
    self = [super init];
    
    //AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    //[del disableCache];
    sprung = NO;
    
    [self setUrl:in_url];
    
    web = nil;
    
    return self;
}

- (void)dealloc {
    [url release];
    [activity release];
    [web release];
    [back release];
    [forward release];
    [super dealloc];
}


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
    [web release];
    web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 420)];
    web.scalesPageToFit = YES;
    web.delegate = self;
    
    [web loadRequest:[NSURLRequest requestWithURL:url]];
    
    self.view = web;
}



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)loadToolbar
{
    back = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_arrow_left.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    forward = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_arrow_right.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshPage)];
    UIBarButtonItem *safari = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(openInSafari)];
    
    UIBarButtonItem *fixed = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixed.width = 20;
    
    UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activity = [[UIBarButtonItem alloc] initWithCustomView:act];
    [act release];

    NSArray *items = [NSArray arrayWithObjects:back, fixed, forward, flex, activity, fixed, refresh, fixed, safari, nil];
    [self setToolbarItems:items];
    
    [flex release];
    [refresh release];
    [safari release];
    [fixed release];
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if([[request.URL host] isEqualToString:@"itunes.apple.com"] || [[request.URL host] isEqualToString:@"phobos.apple.com"]) {
        if(!sprung) {
            sprung = YES;
            [[UIApplication sharedApplication] openURL:request.URL];
            return YES;
        }
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    back.enabled = [webView canGoBack];
    forward.enabled = [webView canGoForward];
    web = webView;
    
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    UIActivityIndicatorView *act = (UIActivityIndicatorView *)activity.customView;
    [act startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    UIActivityIndicatorView *act = (UIActivityIndicatorView *)activity.customView;
    [act stopAnimating];
}

-(void)goBack
{
    [web goBack];
}

-(void)goForward
{
    [web goForward];
}

-(void)refreshPage
{
    [web reload];
}

-(void)openInSafari
{
    [[UIApplication sharedApplication] openURL:web.request.URL];
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
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
    self.navigationItem.rightBarButtonItem = done;
    [done release];
    
    [self loadToolbar];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


@end
