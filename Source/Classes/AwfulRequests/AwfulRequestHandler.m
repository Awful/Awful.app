//
//  AwfulRequestHandler.m
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulRequestHandler.h"
#import "ASINetworkQueue.h"
#import "MBProgressHUD.h"
#import "AwfulAppDelegate.h"
#import "AwfulNavigator.h"
#import "AwfulPageRefreshRequest.h"
#import "AwfulPage.h"
#import "AwfulSplitViewController.h"

@implementation AwfulRequestHandler

@synthesize queue, hud, requests;

-(id)init
{
    if((self=[super init])) {
        self.queue = [[ASINetworkQueue alloc] init];
        self.hud = nil;
        self.requests = [[NSMutableArray alloc] init];
    }
    return self;
}


-(void)cancelAllRequests
{
    for(ASIHTTPRequest *req in self.requests) {
        [req setDelegate:nil];
    }
    [self.queue cancelAllOperations];
    [self hideHud];
}

-(void)loadRequest : (ASIHTTPRequest *)req
{   
    [self.requests addObject:req];
    [self.queue addOperation:req];
    [req setDelegate:self];
    [self.queue go];
}

-(void)loadRequestAndWait : (ASIHTTPRequest *)req
{
    [self showHud];
    self.hud.mode = MBProgressHUDModeIndeterminate;
    
    NSString *msg = [req.userInfo objectForKey:@"loadingMsg"];
    if(msg == nil) {
        msg = @"Loading...";
    }
    
    self.hud.labelText = msg;
    
    [self.requests addObject:req];
    [req setDelegate:self];
    [self.queue addOperation:req];
    [self.queue go];
}

-(void)loadAllWithMessage : (NSString *)msg forRequests : (id)first, ...
{
    NSMutableArray *reqs = [NSMutableArray array];
    
    va_list args;
    va_start(args, first);
    for(ASIHTTPRequest *req = first; req != nil; req = va_arg(args, ASIHTTPRequest *)) {
        [reqs addObject:req];
    }
    va_end(args);
    
    [self showHud];
    self.hud.mode = MBProgressHUDModeIndeterminate;
    self.hud.labelText = msg;
    [self.queue addOperations:reqs waitUntilFinished:NO];
    [[reqs lastObject] setDelegate:self];
    [self.queue go];
}

-(void)showHud
{
    [self hideHud];
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    UIView *view;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        view = ((AwfulAppDelegateIpad *)del).splitController.pageController.view;
    }
    else
    {
        view = del.window;
    }
    self.hud = [[MBProgressHUD alloc] initWithView:view];
    [view addSubview:self.hud];
    self.hud.delegate = self;
    [self.hud show:YES];
}

#pragma mark ASIHTTPRequest Delegate

-(void)requestFinished : (ASIHTTPRequest *)request
{
    [self.requests removeObject:request];
    
    if(self.hud != nil) {
        NSString *msg = [request.userInfo objectForKey:@"completionMsg"];
        if(msg != nil) {
            self.hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
            self.hud.mode = MBProgressHUDModeCustomView;
            self.hud.labelText = msg;
            [NSTimer scheduledTimerWithTimeInterval:1.25 target:self selector:@selector(hideHud) userInfo:nil repeats:NO];
        } else {
            [self hideHud];
        }
    }
    
    AwfulNavigator *nav = getNavigator();
    
    NSString *ref = [request.userInfo objectForKey:@"refresh"];
    if(ref != nil) {
        [nav refresh];
    }
    
    NSString *scroll = [request.userInfo objectForKey:@"scrollToBottom"];
    if(scroll != nil) {
        [nav.contentVC scrollToBottom];
    }
}

-(void)requestFailed : (ASIHTTPRequest *)request
{
    [self.requests removeObject:request];
    [self hideHud];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Request Failed" message:request.error.localizedDescription delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
}

#pragma mark MBProgressHUD Delegate

-(void)hudWasHidden : (MBProgressHUD *)hud 
{
    [self hideHud];
}

-(void)hideHud
{
    [self.hud removeFromSuperview];
    self.hud = nil;
}

@end
