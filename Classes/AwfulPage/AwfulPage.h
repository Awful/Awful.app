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

@interface AwfulPage : UIViewController <AwfulNavigatorContent, UIWebViewDelegate, AwfulHistoryRecorder, UIGestureRecognizerDelegate, JSBridgeWebViewDelegate> {
    AwfulThread *_thread;
    NSString *_url;
    AwfulPageDestinationType _destinationType;
    
    NSMutableArray *_allRawPosts;
    
    BOOL _isBookmarked;
    BOOL _shouldScrollToBottom;
    NSString *_scrollToPostID;
    BOOL _touchedPage;
    
    AwfulNavigator *__weak _delegate;
    AwfulPageCount *_pages;
    UILabel *_pagesLabel;
    UILabel *_threadTitleLabel;
    UIButton *_forumButton;
    UIButton *_pagesButton;
    
    NSString *_adHTML;
    
    AwfulSmallPageController *_pageController;
}

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) NSString *url;
@property AwfulPageDestinationType destinationType;

@property (nonatomic, strong) NSMutableArray *allRawPosts;

@property BOOL isBookmarked;
@property BOOL shouldScrollToBottom;
@property (nonatomic, strong) NSString *scrollToPostID;
@property BOOL touchedPage;

@property (nonatomic, weak) AwfulNavigator *delegate;
@property (nonatomic, strong) AwfulPageCount *pages;
@property (nonatomic, strong) UILabel *pagesLabel;
@property (nonatomic, strong) UILabel *threadTitleLabel;
@property (nonatomic, strong) IBOutlet UIButton *forumButton;
@property (nonatomic, strong) UIButton *pagesButton;

@property (nonatomic, strong) NSString *adHTML;

@property (nonatomic, strong) AwfulSmallPageController *pageController;

-(id)initWithAwfulThread : (AwfulThread *)thread startAt : (AwfulPageDestinationType)thread_pos;
-(id)initWithAwfulThread : (AwfulThread *)thread pageNum : (int)page_num;
-(id)initWithAwfulThread : (AwfulThread *)thread startAt : (AwfulPageDestinationType)thread_pos pageNum : (int)page_num;
-(void)acceptPosts : (NSMutableArray *)posts;

-(NSString *)getURLSuffix;

-(void)hardRefresh;
-(void)setThreadTitle : (NSString *)in_title;
-(void)tappedPageNav : (id)sender;

-(void)scrollToSpecifiedPost;
-(void) showActions:(NSString *)post_id;
-(void)setWebView : (JSBridgeWebView *)webView;
-(void)loadOlderPosts;
-(void)nextPage;
-(void)prevPage;

-(void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer;
-(void)scrollToPost : (NSString *)post_id;


@end


@interface AwfulPageIpad : AwfulPage <UIPickerViewDataSource, UIPickerViewDelegate> {
    UIBarButtonItem *_pageButton;
    UIBarButtonItem *_ratingButton;
    UIPopoverController *_popController;
    UIPickerView *_pagePicker;
    CGPoint _lastTouch;
    AwfulActions *_actions;
}
@property (nonatomic, strong) UIBarButtonItem *pageButton;
@property (nonatomic, strong) UIBarButtonItem *ratingButton;
@property (nonatomic, strong) UIPopoverController *popController;
@property (nonatomic, strong) UIPickerView *pagePicker;
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