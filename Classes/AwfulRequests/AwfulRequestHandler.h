//
//  AwfulRequestHandler.h
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"
#import "MBProgressHUD.h"

@class ASINetworkQueue;

@interface AwfulRequestHandler : NSObject <ASIHTTPRequestDelegate, MBProgressHUDDelegate> {
    ASINetworkQueue *_queue;
    MBProgressHUD *_hud;
    NSMutableArray *_requests;
}

@property (nonatomic, retain) ASINetworkQueue *queue;
@property (nonatomic, retain) MBProgressHUD *hud;
@property (nonatomic, retain) NSMutableArray *requests;

-(void)showHud;
-(void)hideHud;
-(void)cancelAllRequests;
-(void)loadRequest : (ASIHTTPRequest *)req;
-(void)loadRequestAndWait : (ASIHTTPRequest *)req;
-(void)loadAllWithMessage : (NSString *)msg forRequests : (id) first, ... NS_REQUIRES_NIL_TERMINATION;


@end
