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
#import "AwfulHistory.h"
#import "AwfulNavigator.h"
#import "JSBridgeWebView.h"

typedef enum {
    AwfulPageDestinationTypeFirst,
    AwfulPageDestinationTypeLast,
    AwfulPageDestinationTypeNewpost,
    AwfulPageDestinationTypeSpecific
} AwfulPageDestinationType;

@class AwfulPageCount;
@class AwfulSmallPageController;
@class AwfulPageDataController;
@class AwfulActions;

@interface AwfulPage : UIViewController <AwfulNavigatorContent, UIWebViewDelegate, AwfulHistoryRecorder, UIGestureRecognizerDelegate, JSBridgeWebViewDelegate>

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, assign) AwfulPageDestinationType destinationType;

@property BOOL isBookmarked;
@property BOOL shouldScrollToBottom;
@property (nonatomic, strong) NSString *postIDScrollDestination;
@property BOOL touchedPage;

@property (nonatomic, strong) AwfulActions *actions;
@property (nonatomic, weak) AwfulNavigator *navigator;
@property (nonatomic, strong) AwfulPageCount *pages;
@property (nonatomic, strong) UILabel *pagesLabel;
@property (nonatomic, strong) UILabel *threadTitleLabel;
@property (nonatomic, strong) IBOutlet UIButton *forumButton;
@property (nonatomic, strong) UIButton *pagesButton;

@property (nonatomic, strong) AwfulPageDataController *dataController;
@property (nonatomic, strong) AwfulSmallPageController *pageController;
@property (nonatomic, strong) MKNetworkOperation *networkOperation;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *pagesBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *nextPageBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *bookmarksBarButtonItem;

+(id)pageWithAwfulThread : (AwfulThread *)aThread startAt : (AwfulPageDestinationType)thread_pos;
+(id)pageWithAwfulThread : (AwfulThread *)aThread pageNum : (int)page_num;
+(id)pageWithAwfulThread : (AwfulThread *)aThread startAt : (AwfulPageDestinationType)thread_pos pageNum : (int)page_num;
+(id)pageWithAwfulHistory : (AwfulHistory *)history;

-(id)initWithAwfulThread : (AwfulThread *)aThread startAt : (AwfulPageDestinationType)thread_pos;
-(id)initWithAwfulThread : (AwfulThread *)aThread pageNum : (int)page_num;
-(id)initWithAwfulThread : (AwfulThread *)aThread startAt : (AwfulPageDestinationType)thread_pos pageNum : (int)page_num;
-(void)acceptPosts : (NSMutableArray *)posts;

-(NSString *)getURLSuffix;

-(IBAction)hardRefresh;
-(void)setThreadTitle : (NSString *)in_title;


-(IBAction)tappedPageNav : (id)sender;
-(IBAction)tappedBookmarks : (id)sender;
-(IBAction)tappedVote : (id)sender;
-(IBAction)tappedCompose : (id)sender;
-(IBAction)tappedNextPage : (id)sender;

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


@interface AwfulPageIpad : AwfulPage <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, strong) UIBarButtonItem *pageButton;
@property (nonatomic, strong) UIBarButtonItem *ratingButton;
@property (nonatomic, strong) UIPopoverController *popController;
@property (nonatomic, strong) UIPickerView *pagePicker;
@property CGPoint lastTouch;
@property (nonatomic, strong) AwfulActions *actions;

-(void)makeCustomToolbars;
-(void)hitActions;
-(void)hitMore;
-(void)pageSelection;
-(void)gotoPageClicked;
-(void)hitForum;
-(void)handleTap:(UITapGestureRecognizer *)sender;
-(void)rateThread:(id)sender;
-(void)bookmarkThread:(id)sender;
-(void)reply;
-(void)backPage;

@end