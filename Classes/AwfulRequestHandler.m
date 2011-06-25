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

@implementation AwfulRequestHandler

@synthesize queue = _queue;
@synthesize hud = _hud;

-(id)init
{
    _queue = [[ASINetworkQueue alloc] init];
    _hud = nil;
    return self;
}

-(void)dealloc
{
    [_queue release];
    [_hud release];
    [super dealloc];
}

-(void)loadRequest : (ASIHTTPRequest *)req
{   
    [self.queue addOperation:req];
    [req setDelegate:self];
    [self.queue go];
}

-(void)loadRequestAndWait : (ASIHTTPRequest *)req
{
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    self.hud = [[[MBProgressHUD alloc] initWithView:del.window] autorelease];
    [del.window addSubview:self.hud];
    self.hud.delegate = self;
    self.hud.mode = MBProgressHUDModeIndeterminate;
    self.hud.labelText = @"Loading...";
    [self.hud show:YES];
    [[self queue] addOperation:req];
    [req setDelegate:self];
    [self.queue go];
}

-(void)loadAllWithMessage : (NSString *)msg forRequests : (id)first, ...
{
    NSMutableArray *requests = [NSMutableArray array];
    
    va_list args;
    va_start(args, first);
    for(ASIHTTPRequest *req = first; req != nil; req = va_arg(args, ASIHTTPRequest *)) {
        [requests addObject:req];
    }
    va_end(args);
    

    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    self.hud = [[[MBProgressHUD alloc] initWithView:del.window] autorelease];
    [del.window addSubview:self.hud];
    self.hud.delegate = self;
    self.hud.mode = MBProgressHUDModeIndeterminate;
    self.hud.labelText = msg;
    [self.hud show:YES];
    [self.queue addOperations:requests waitUntilFinished:NO];
    [[requests lastObject] setDelegate:self];
    [self.queue go];
}

#pragma mark ASIHTTPRequest Delegate

-(void)requestFinished : (ASIHTTPRequest *)request
{
    if(self.hud != nil) {
        NSString *msg = [request.userInfo objectForKey:@"completionMsg"];
        if(msg != nil) {
            self.hud.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]] autorelease];
            self.hud.mode = MBProgressHUDModeCustomView;
            self.hud.labelText = msg;
            [NSTimer scheduledTimerWithTimeInterval:1.25 target:self selector:@selector(hideHud) userInfo:nil repeats:NO];
        } else {
            [self hideHud];
        }
    }
    NSString *ref = [request.userInfo objectForKey:@"refresh"];
    if(ref != nil) {
        AwfulNavigator *nav = getNavigator();
        [nav refresh];
    }
}

-(void)requestFailed : (ASIHTTPRequest *)request
{
    if(self.hud != nil) {
        self.hud.mode = MBProgressHUDModeCustomView;
        self.hud.labelText = @"Failed";
        [NSTimer scheduledTimerWithTimeInterval:1.25 target:self selector:@selector(hideHud) userInfo:nil repeats:NO];
    }
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
