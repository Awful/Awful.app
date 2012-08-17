//
//  AwfulRefreshControl.h
//  Awful
//
//  Created by me on 6/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    AwfulRefreshControlStateNormal = UIControlStateNormal,
    AwfulRefreshControlStatePulling = 0x00010000,
    AwfulRefreshControlStateLoading = 0x00020000,
    AwfulRefreshControlStateParsing = 0x00030000,
    AwfulRefreshControlStatePageTransition = 0x00040000
} AwfulRefreshControlState;

@interface AwfulRefreshControl : UIControl {
    UIActivityIndicatorView *_activityView;
    
    @protected
    AwfulRefreshControlState _state;
}
//- (void)beginRefreshing;
//- (void)endRefreshing;
- (void)didScrollInScrollView:(UIScrollView*)scrollView;
-(NSString*) stringTimeIntervalSinceLoad;
-(void) changeLabelTextForCurrentState;

@property (nonatomic,readonly) UILabel* title;
@property (nonatomic,readonly) UILabel* subtitle;
@property (nonatomic,readonly) UIActivityIndicatorView* activityView;
@property (nonatomic, readonly) UIImageView* imageView;
@property (nonatomic, readonly) UIImageView* imageView2;
@property (nonatomic,readonly) UITableViewCell* innerCell;

@property (nonatomic,readwrite) CGFloat scrollAmount;
@property (nonatomic,strong) UIScrollView* scrollView;
@property (nonatomic,readwrite) AwfulRefreshControlState state;
@property (nonatomic,strong) NSDate* loadedDate;

@property (nonatomic, readonly, getter=isRefreshing) BOOL refreshing;
@property (nonatomic, readwrite) BOOL userScrolling;
@property (nonatomic, readwrite) BOOL changeInsetToShow;
@property (nonatomic, readwrite) BOOL canSwipeToCancel;
@end
