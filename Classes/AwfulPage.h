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
#import "AwfulNavigator.h"

typedef enum {
    AwfulPageDestinationTypeFirst,
    AwfulPageDestinationTypeLast,
    AwfulPageDestinationTypeNewpost,
    AwfulPageDestinationTypeSpecific
} AwfulPageDestinationType;

@class AwfulPageCount;

#define MIN_PORTRAIT_HEIGHT 75
#define MIN_LANDSCAPE_HEIGHT 75
#define TOUCH_POST 1
#define PAGE_TAG 5
#define THREAD_TITLE_LABEL 2

@class ThreadNavigationView;

@interface AwfulPage : PullRefreshTableViewController <UIWebViewDelegate, AwfulHistoryRecorder, UIGestureRecognizerDelegate> {
    AwfulThread *_thread;
    NSString *_url;
    
    NSMutableArray *_allRawPosts;
    NSMutableArray *_renderedPosts;
    NSMutableArray *_readPosts;
    NSMutableArray *_unreadPosts;
  
    AwfulHistory *_pageHistory;
    AwfulPost *_highlightedPost;
    
    BOOL _isBookmarked;
    
    int _totalLoading;
    int _totalFinished;
    
    int _newPostIndex;
    
    UIWebView *_ad;
    NSString *_adHTML;
}

@property (nonatomic, retain) AwfulThread *thread;
@property (nonatomic, retain) AwfulHistory *pageHistory;
@property (nonatomic, retain) NSString *url;
@property (nonatomic, retain) UIWebView *ad;
@property (nonatomic, retain) NSString *adHTML;
@property (nonatomic, retain) AwfulPost *highlightedPost;

@property BOOL isBookmarked;
@property int totalLoading;
@property int totalFinished;
@property int newPostIndex;

@property (nonatomic, retain) NSMutableArray *allRawPosts;
@property (nonatomic, retain) NSMutableArray *renderedPosts;
@property (nonatomic, retain) NSMutableArray *readPosts;
@property (nonatomic, retain) NSMutableArray *unreadPosts;


-(id)initWithAwfulThread : (AwfulThread *)in_thread startAt : (AwfulPageDestinationType)thread_pos;
-(id)initWithAwfulThread : (AwfulThread *)in_thread startAt : (AwfulPageDestinationType)thread_pos pageNum : (int)page_num;
-(void)acceptPosts : (NSMutableArray *)posts;
-(void)acceptAd : (NSString *)ad_html;

-(NSString *)getURLSuffix;
-(void)makeButtons;

-(void)hardRefresh;
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

@end

float getWidth();
float getMinHeight();
