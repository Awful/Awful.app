//
//  AwfulRefreshControl.h
//  Awful
//
//  Created by me on 6/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    AwfulRefreshControlStatePulling = 0,
    AwfulRefreshControlStateNormal,
    AwfulRefreshControlStateLoading,
} AwfulRefreshControlState;

@interface AwfulRefreshControl : UIControl
//- (void)beginRefreshing;
//- (void)endRefreshing;
- (void)didScrollInScrollView:(UIScrollView*)scrollView;
-(NSString*) stringTimeIntervalSinceLoad;

@property (nonatomic,readonly) UILabel* title;
@property (nonatomic,readonly) UILabel* subtitle;
@property (nonatomic,readonly) UIActivityIndicatorView* activityView;
@property (nonatomic, readonly) UIImageView* imageView;
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
