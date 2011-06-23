//
//  AwfulNavigator.h
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulContentViewController;
@class ASIHTTPRequest;
@class AwfulRequestHandler;
@class AwfulPageCount;
@class AwfulTableViewController;
@class AwfulUser;

@interface AwfulNavigator : UIViewController {
    UIToolbar *_toolbar;
    AwfulTableViewController *_contentVC;
    AwfulRequestHandler *_requestHandler;
    AwfulUser *_user;
}

@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) AwfulTableViewController *contentVC;
@property (nonatomic, retain) AwfulRequestHandler *requestHandler;
@property (nonatomic, retain) AwfulUser *user;

-(void)loadContentVC : (AwfulTableViewController *)content;
-(void)loadOtherView : (UIView *)other_view;

-(IBAction)tappedBack;
-(IBAction)tappedForumsList;
-(IBAction)tappedAction;
-(IBAction)tappedBookmarks;
-(IBAction)tappedMore;

-(void)tappedThreeTimes : (UITapGestureRecognizer *)gesture;

-(void)callBookmarksRefresh;

@end

AwfulNavigator *getNavigator();
void loadContentVC(AwfulTableViewController *content);
void loadRequest(ASIHTTPRequest *req);
void loadRequestAndWait(ASIHTTPRequest *req);
