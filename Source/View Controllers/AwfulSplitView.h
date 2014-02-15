//  AwfulSplitView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
@protocol AwfulSplitViewDelegate;

/**
 * An AwfulSplitView lays out the views for an AwfulSplitViewController.
 */
@interface AwfulSplitView : UIView

@property (strong, nonatomic) UIView *masterView;

/**
 * Setting detailView is equivalent to calling -setDetailView:animated: and passing NO for the second parameter.
 */
@property (strong, nonatomic) UIView *detailView;

/**
 * If the second parameter is YES, the old detail view quickly fades into the new detail view.
 */
- (void)setDetailView:(UIView *)detailView animated:(BOOL)animated;

@property (assign, nonatomic) BOOL masterViewHidden;

@property (assign, nonatomic) BOOL masterViewStuckVisible;

@property (weak, nonatomic) id <AwfulSplitViewDelegate> delegate;

@end

@protocol AwfulSplitViewDelegate <NSObject>

/**
 * Informs the delegate that the detail view was tapped while the master view was visible (but not stuck visible).
 */
- (void)splitViewDidTapDetailViewWhenMasterViewVisible:(AwfulSplitView *)splitView;

/**
 * Informs the delegate that the detail view was swiped while the master view was hidden.
 */
- (void)splitViewDidSwipeToShowMasterView:(AwfulSplitView *)splitView;

@end
