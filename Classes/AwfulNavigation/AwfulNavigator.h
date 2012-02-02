//
//  AwfulNavigator.h
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulHistory.h"

@class AwfulContentViewController;
@class ASIHTTPRequest;
@class AwfulRequestHandler;
@class AwfulPageCount;
@class AwfulUser;
@class AwfulNavigator;
@class AwfulActions;
@class AwfulHistoryManager;

@protocol AwfulNavigatorContent <NSObject, AwfulHistoryRecorder>

-(UIView *)getView;
-(void)setDelegate : (AwfulNavigator *)delegate;
-(void)refresh;
-(void)stop;
-(AwfulActions *)getActions;
-(void)scrollToBottom;

@end

@interface AwfulNavigator : UIViewController <UINavigationControllerDelegate, UIGestureRecognizerDelegate> {
    UIToolbar *_toolbar;
    id<AwfulNavigatorContent> _contentVC;
    AwfulRequestHandler *_requestHandler;
    AwfulUser *_user;
    AwfulActions *_actions;
    AwfulHistoryManager *_historyManager;
    UIBarButtonItem *_backButton;
    UIBarButtonItem *_forwardButton;
    UIBarButtonItem *_actionButton;
    UILabel *_welcomeMessage;
    UIButton *_fullScreenButton;
}

@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) id<AwfulNavigatorContent> contentVC;
@property (nonatomic, strong) AwfulRequestHandler *requestHandler;
@property (nonatomic, strong) AwfulUser *user;
@property (nonatomic, strong) AwfulActions *actions;
@property (nonatomic, strong) AwfulHistoryManager *historyManager;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *backButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *forwardButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *actionButton;
@property (nonatomic, strong) IBOutlet UILabel *welcomeMessage;
@property (nonatomic, strong) IBOutlet UIButton *fullScreenButton;

-(void)loadContentVC : (id<AwfulNavigatorContent>)content;

-(void)refresh;
-(void)stop;
-(void)swapToRefreshButton;
-(void)swapToStopButton;
-(void)updateHistoryButtons;
-(IBAction)tappedBack;
-(IBAction)tappedForward;
-(IBAction)tappedForumsList;
-(IBAction)tappedAction;
-(IBAction)tappedBookmarks;
-(IBAction)tappedMore;

-(void)didFullscreenGesture : (UIGestureRecognizer *)gesture;
-(IBAction)tappedFullscreen : (id)sender;
-(void)forceShow;
-(BOOL)isFullscreen;

-(void)callBookmarksRefresh;

@end

@interface AwfulNavigatorIpad : AwfulNavigator

-(void) callForumsRefresh;

@end

AwfulNavigator *getNavigator();
void loadContentVC(id<AwfulNavigatorContent> content);
void loadRequest(ASIHTTPRequest *req);
void loadRequestAndWait(ASIHTTPRequest *req);
