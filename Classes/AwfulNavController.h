//
//  AwfulNavController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulPost.h"
#import "AwfulThreadList.h"
#import "AwfulPage.h"
#import "ASINetworkQueue.h"
#import "ASIHTTPRequest.h"
#import "AwfulUser.h"
#import "VoteDelegate.h"
#import "AwfulPageNavController.h"
#import "AwfulForumRefreshRequest.h"
#import "MBProgressHUD.h"

#define MAX_HISTORY 3
#define MAX_RECORDED_HISTORY 20

@class AwfulLoginController;

@interface AwfulNavController : UINavigationController <UIActionSheetDelegate, UIAlertViewDelegate, MBProgressHUDDelegate> {
    AwfulLoginController *login;
    VoteDelegate *vote;
    
    BOOL displayingPostOptions;
    
    UIViewController *unfiltered;
    
    UIBarButtonItem *back;
    UIBarButtonItem *forward;
    UIBarButtonItem *forumsList;
    UIBarButtonItem *bookmarks;
    UIBarButtonItem *options;
    
    NSMutableArray *history;
    NSMutableArray *forwardHistory;
    NSMutableArray *_recordedHistory;
    NSMutableArray *_recordedForwardHistory;
    
    ASINetworkQueue *queue;
    
    AwfulUser *user;
    AwfulPageNavController *pageNav;
    
    AwfulForumRefreshRequest *bookmarksRefreshReq;
    MBProgressHUD *_hud;
}

@property (nonatomic, retain) ASINetworkQueue *queue;
@property (nonatomic, retain) AwfulUser *user;
@property (nonatomic, retain) AwfulForumRefreshRequest *bookmarksRefreshReq;

@property (nonatomic, retain) NSMutableArray *recordedHistory;
@property (nonatomic, retain) NSMutableArray *recordedForwardHistory;

@property (nonatomic, retain) MBProgressHUD *hud;

-(NSArray *)getToolbarItemsForOrientation : (UIInterfaceOrientation)orient;
-(NSArray *)getToolbarItems;

-(BOOL)isLoggedIn;
-(void)showLogin;

-(void)tappedTop;
-(void)tappedBottom;
-(void)doubleTappedTop;
-(void)doubleTappedBottom;

-(void)checkHistoryButtons;
-(void)addHistory : (id)obj;

-(void)showNotification : (NSString *)msg;

-(void)loadForum : (AwfulThreadList *)forum;
-(void)loadPage : (AwfulPage *)page;

-(void)loadRequest : (ASIHTTPRequest *)req;
-(void)loadRequestAndWait : (ASIHTTPRequest *)req;

-(void)showImage : (NSString *)img_src;

-(void)stopAllRequests;

-(void)showVoteOptions : (AwfulPage *)page;
-(void)showForumOptions;
-(void)showPostOptions : (AwfulPost *)p;
-(void)showThreadOptions;
-(void)showPageNumberNav : (AwfulPage *)page;

-(void)hidePageNav;

-(void)showUnfilteredWithHTML : (NSString *)html;

-(void)goBack;
-(void)goForward;
-(void)openOptions;
-(void)openBookmarks;
-(void)openForums;

-(void)purge;
-(void)hideHud;

-(void)callBookmarksRefresh;

-(void)requestFailed : (ASIHTTPRequest *)request;

@end

@protocol WaitRequestCallback

-(void)success;
-(void)failed;

@end

AwfulNavController *getnav();
int getPostsPerPage();
NSString *getUsername();
