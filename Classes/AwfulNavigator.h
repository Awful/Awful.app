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

@protocol AwfulNavigatorContent <NSObject>

-(UIView *)getView;
-(void)setDelegate : (AwfulNavigator *)delegate;
-(void)refresh;
-(void)stop;

@end

@interface AwfulNavigator : UIViewController <UINavigationControllerDelegate, UIGestureRecognizerDelegate> {
    UIToolbar *_toolbar;
    id<AwfulNavigatorContent> _contentVC;
    AwfulRequestHandler *_requestHandler;
    AwfulUser *_user;
}

@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) id<AwfulNavigatorContent> contentVC;
@property (nonatomic, retain) AwfulRequestHandler *requestHandler;
@property (nonatomic, retain) AwfulUser *user;

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
