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
#import "TFHpple.h"
#import "AwfulPostBoxController.h"
#import "JSBridgeWebView.h"

typedef enum {
    AwfulPageDestinationTypeFirst,
    AwfulPageDestinationTypeLast,
    AwfulPageDestinationTypeNewpost,
    AwfulPageDestinationTypeSpecific
} AwfulPageDestinationType;

@class AwfulPageCount;
@class AwfulSpecificPageViewController;
@class AwfulPageDataController;
@class AwfulActions;
@class ButtonSegmentedControl;

@interface AwfulPage : UIViewController <UIWebViewDelegate, UIGestureRecognizerDelegate, JSBridgeWebViewDelegate>

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, assign) AwfulPageDestinationType destinationType;
@property (nonatomic, strong) IBOutlet JSBridgeWebView *webView;
@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;

@property BOOL isBookmarked;
@property BOOL shouldScrollToBottom;
@property (nonatomic, strong) NSString *postIDScrollDestination;
@property BOOL touchedPage;

@property (nonatomic, strong) AwfulActions *actions;
@property (nonatomic, strong) AwfulPageCount *pages;

@property (nonatomic, strong) AwfulPageDataController *dataController;
@property (nonatomic, strong) AwfulSpecificPageViewController *specificPageController;
@property (nonatomic, strong) MKNetworkOperation *networkOperation;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *pagesBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *nextPageBarButtonItem;

@property (nonatomic, strong) IBOutlet ButtonSegmentedControl *pagesSegmentedControl;
@property (nonatomic, strong) IBOutlet ButtonSegmentedControl *actionsSegmentedControl;

@property (nonatomic, assign) BOOL draggingUp;

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
-(void)stop;

-(void)scrollToSpecifiedPost;
-(void)showActions:(NSString *)post_id;
-(void)setWebView : (JSBridgeWebView *)webView;
-(void)loadOlderPosts;
-(void)nextPage;
-(void)prevPage;

-(void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer;
-(void)scrollToPost : (NSString *)post_id;
-(void)swapToStopButton;
-(void)swapToRefreshButton;

@end
