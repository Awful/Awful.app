//
//  LoginController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "LoginController.h"
#import "AwfulAppDelegate.h"
#import "AwfulNavController.h"

@implementation LoginController

@synthesize web;


 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil controller : (AwfulNavController *)controller {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        act = nil;
    }
    return self;
}


- (void)dealloc {
    [act release];
    [super dealloc];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com/account.php?action=loginform"];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    web.scalesPageToFit = YES;
    web.delegate = self;
    [web loadRequest:req];
    
    [act release];
    act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    act.center = CGPointMake(160, 100);
    [act startAnimating];
    [web addSubview:act];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(hitCancel)];
    self.navigationItem.rightBarButtonItem = done;
    [done release];
}

-(void)hitCancel
{
    AwfulNavController *nav = getnav();
    [nav dismissModalViewControllerAnimated:YES];
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSURLRequest *req = webView.request;
    if([[req.URL relativePath] isEqualToString:@"/index.php"]) {
        web.delegate = nil;
        AwfulNavController *nav = getnav();
        [nav.user loadUser];
        [nav dismissModalViewControllerAnimated:NO];
        [nav openForums];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [act removeFromSuperview];
    [act stopAnimating];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

@end
