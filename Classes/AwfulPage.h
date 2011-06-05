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
#import "PullRefreshTableViewController.h"

enum {
    THREAD_POS_FIRST,
    THREAD_POS_LAST,
    THREAD_POS_NEWPOST,
    THREAD_POS_SPECIFIC
};

#define MIN_PORTRAIT_HEIGHT 75
#define MIN_LANDSCAPE_HEIGHT 75
#define TOUCH_POST 1
#define PAGE_TAG 5
#define THREAD_TITLE_LABEL 2

@class ThreadNavigationView;

@interface AwfulPage : PullRefreshTableViewController <UIWebViewDelegate, AwfulHistoryRecorder, UIGestureRecognizerDelegate> {
    AwfulThread *thread;
    NSString *currentURL;
    
    NSMutableArray *_allRawPosts;
    NSMutableArray *_renderedPosts;
    NSMutableArray *_readPosts;
    NSMutableArray *_unreadPosts;
  
    PageManager *pages; 
    AwfulHistory *pageHistory;
    
    AwfulPost *highlightedPost;
    
    BOOL isBookmarked;
    BOOL isReplying;
    
    int totalLoading;
    int totalFinished;
    
    int newPostIndex;
    int oldRotationRow;
    
    UIImageView *titleBar;
    UIButton *refreshButton;
    UIButton *stopButton;
    UIButton *nextPageButton;
    UIButton *prevPageButton;
    
    UIWebView *ad;
    NSString *adHTML;
}

@property (nonatomic, retain) AwfulThread *thread;
@property (nonatomic, retain) PageManager *pages;
@property (nonatomic, retain) AwfulHistory *pageHistory;
@property (nonatomic, retain) NSString *currentURL;
@property (nonatomic, retain) UIWebView *ad;
@property (nonatomic, assign) int newPostIndex;
@property (nonatomic, retain) NSString *adHTML;

@property (nonatomic, retain) NSMutableArray *allRawPosts;
@property (nonatomic, retain) NSMutableArray *renderedPosts;
@property (nonatomic, retain) NSMutableArray *readPosts;
@property (nonatomic, retain) NSMutableArray *unreadPosts;

@property BOOL isBookmarked;

-(id)initWithAwfulThread : (AwfulThread *)in_thread startAt : (int)thread_pos;
-(id)initWithAwfulThread : (AwfulThread *)in_thread startAt : (int)thread_pos pageNum : (int)page_num;
-(void)acceptPosts : (NSMutableArray *)posts;
-(void)acceptAd : (NSString *)ad_html;

-(NSString *)getURLSuffix;
-(void)makeButtons;

-(void)swapToView : (UIView *)v;
-(void)refresh;
-(void)hardRefresh;
-(void)stop;
-(void)setThreadTitle : (NSString *)in_title;

-(UIWebView *)newWebViewFromAwfulPost : (AwfulPost *)post;

-(void)scrollToRow : (int)row;

-(void)doneLoadingPage;
-(void)nextPage;
-(void)prevPage;

-(void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer;
-(void)imageGesture : (UITapGestureRecognizer *)sender;
-(void)chosePostOption : (int)option;
-(void)choseThreadOption : (int)option;

-(int)getTypeAtIndexPath : (NSIndexPath *)path;
-(UIWebView *)getRenderedPostAtIndexPath : (NSIndexPath *)path;
-(NSUInteger)getRowForWebView : (UIWebView *)web;

-(void)reverifyHeights;
-(BOOL)rowCheck : (int)row;

-(void)slideDown;
-(void)slideUp;
-(void)slideToBottom;
-(void)slideToTop;

@end

float getWidth();
float getMinHeight();
