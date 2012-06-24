//
//  AwfulPage.h
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulThread.h"
#import "AwfulPost.h"
#import "AwfulPostBoxController.h"
#import "AwfulPullForActionController.h"
#import "AwfulWebViewDelegate.h"

typedef enum {
    AwfulPageDestinationTypeFirst,
    AwfulPageDestinationTypeLast,
    AwfulPageDestinationTypeNewpost,
    AwfulPageDestinationTypeSpecific
} AwfulPageDestinationType;

@class AwfulSpecificPageViewController;
@class AwfulPageDataController;
@class AwfulActions;
@class ButtonSegmentedControl;
@class AwfulLoadingFooterView;
@class AwfulLoadingHeaderView;

@interface AwfulPage : UIViewController <AwfulWebViewDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate,AwfulPullForActionDelegate>
{
@protected
    AwfulActions *_actions;
}

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) NSString *threadID;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, assign) AwfulPageDestinationType destinationType;
@property (nonatomic, strong) IBOutlet UIWebView *webView;
@property (nonatomic, strong) UIWebView *nextPageWebView;
@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;

@property BOOL isBookmarked;
@property BOOL shouldScrollToBottom;
@property (nonatomic, strong) NSString *postIDScrollDestination;

@property (nonatomic, strong) AwfulActions *actions;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger numberOfPages;

@property (nonatomic, strong) AwfulPageDataController *dataController;
@property (nonatomic, strong) AwfulSpecificPageViewController *specificPageController;
@property (nonatomic, strong) NSOperation *networkOperation;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *pagesBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *nextPageBarButtonItem;

@property (nonatomic, strong) IBOutlet ButtonSegmentedControl *pagesSegmentedControl;
@property (nonatomic, strong) IBOutlet ButtonSegmentedControl *actionsSegmentedControl;

@property (nonatomic, assign) BOOL draggingUp;
@property (nonatomic, assign) BOOL isFullScreen;

@property (nonatomic, strong) AwfulLoadingFooterView* loadingFooterView;
@property (nonatomic, strong) AwfulLoadingHeaderView* loadingHeaderView;
@property (nonatomic, strong) AwfulPullForActionController* pullForActionController;

@property (nonatomic,strong) NSTimer* autoRefreshTimer;

-(IBAction)hardRefresh;
-(void)setThreadTitle : (NSString *)in_title;

-(void)updatePagesLabel;

-(IBAction)tappedActions:(id)sender;
-(IBAction)tappedPageNav : (id)sender;
-(IBAction)tappedNextPage : (id)sender;

-(IBAction)segmentedGotTapped : (id)sender;
-(IBAction)tappedPagesSegment : (id)sender;
-(IBAction)tappedActionsSegment : (id)sender;

-(void)refresh;
-(void)loadPageNum : (NSUInteger)pageNum;
-(void)loadLastPage;
-(void)stop;

-(void)scrollToSpecifiedPost;
- (void)showActions:(NSString *)post_id fromRect:(CGRect)rect;
-(void)showActions;
-(void)loadOlderPosts;
-(void)nextPage;
-(void)prevPage;

-(void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer;
-(void)didFullscreenGesture : (UIGestureRecognizer *)gesture;
-(void)scrollToPost : (NSString *)post_id;
-(void)swapToStopButton;
-(void)swapToRefreshButton;

-(void)showCompletionMessage : (NSString *)message;
-(void)hidePageNavigation;


-(void) didSwitchAutoF5:(UISwitch*)switchObj;

@end

#import "AwfulSplitViewController.h"

@interface AwfulPageIpad: AwfulPage <SubstitutableDetailViewController, UIGestureRecognizerDelegate>
{
    CGPoint _lastTouch;
}

@property (nonatomic, strong) UIPopoverController *popController;

- (void)handleTap:(UITapGestureRecognizer *)sender;
@end
