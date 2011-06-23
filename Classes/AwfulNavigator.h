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
@class AwfulUser;
@class AwfulNavigator;
@class AwfulActions;
@class AwfulPageNavController;

@protocol AwfulNavigatorContent <NSObject>

-(UIView *)getView;
-(void)setDelegate : (AwfulNavigator *)delegate;
-(void)refresh;
-(void)stop;
-(AwfulActions *)getActions;

@end

@interface AwfulNavigator : UIViewController <UINavigationControllerDelegate, UIGestureRecognizerDelegate> {
    UIToolbar *_toolbar;
    id<AwfulNavigatorContent> _contentVC;
    AwfulRequestHandler *_requestHandler;
    AwfulUser *_user;
    AwfulActions *_actions;
    AwfulPageNavController *_pageNav;
}

@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) id<AwfulNavigatorContent> contentVC;
@property (nonatomic, retain) AwfulRequestHandler *requestHandler;
@property (nonatomic, retain) AwfulUser *user;
@property (nonatomic, retain) AwfulActions *actions;
@property (nonatomic, retain) AwfulPageNavController *pageNav;

-(void)loadContentVC : (id<AwfulNavigatorContent>)content;

-(void)refresh;
-(void)stop;
-(void)swapToRefreshButton;
-(void)swapToStopButton;
-(IBAction)tappedBack;
-(IBAction)tappedForumsList;
-(IBAction)tappedAction;
-(IBAction)tappedBookmarks;
-(IBAction)tappedMore;

-(void)tappedThreeTimes : (UITapGestureRecognizer *)gesture;

-(void)callBookmarksRefresh;

@end

AwfulNavigator *getNavigator();
void loadContentVC(id<AwfulNavigatorContent> content);
void loadRequest(ASIHTTPRequest *req);
void loadRequestAndWait(ASIHTTPRequest *req);
