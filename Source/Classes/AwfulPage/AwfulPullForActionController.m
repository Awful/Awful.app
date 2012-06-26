//
//  AwfulPullForActionController.m
//  Awful
//
//  Created by me on 5/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPullForActionController.h"
#import "AwfulLoadingHeaderView.h"
#import "SRRefreshView.h"

#define EXTRA_PULL_THRESHHOLD 5

@implementation AwfulPullForActionController
@synthesize scrollView = _scrollView;
@synthesize headerView = _headerView;
@synthesize footerView = _footerView;
@synthesize delegate = _delegate;
@synthesize userScrolling = _userScrolling;
@synthesize autoRefreshTimer = _autoRefreshTimer;

#pragma mark Setup
-(id) initWithScrollView:(UIScrollView*)scrollView {
    self = [super init];
    self.scrollView = scrollView;
    scrollView.delegate = self;
    
    return self;
}

-(void) setHeaderView:(UIView<AwfulPullForActionViewDelegate> *)headerView {
    _headerView = headerView;
    
    headerView.frame = CGRectMake(0, -headerView.fsH, self.scrollView.fsW, headerView.fsH);
    [self.scrollView addSubview:headerView];
}

-(void) setFooterView:(UIView<AwfulPullForActionViewDelegate> *)footerView {
    _footerView = footerView;
    footerView.frame = CGRectMake(0, self.scrollView.contentSize.height, self.scrollView.fsW, self.footerView.fsH);
    
    [self.scrollView addSubview:footerView];
    
    if ([footerView respondsToSelector:@selector(autoF5)])
        [footerView.autoF5 addTarget:self 
                        action:@selector(didSwitchAutoF5:) 
              forControlEvents:UIControlEventValueChanged];
}

-(void) setScrollView:(UIScrollView *)scrollView {
    if (scrollView == nil) return;
    _scrollView = scrollView;
    scrollView.delegate = self;
    if (self.headerView) {
        if (self.headerView.superview != scrollView) {
            [self.headerView removeFromSuperview];
            [self.scrollView addSubview:self.headerView];
        }
        self.headerView.frame = CGRectMake(0, -self.headerView.fsH, self.scrollView.fsW, self.headerView.fsH);
    }
    
    if (self.footerView) {
        if (self.footerView.superview != scrollView) {
            [self.footerView removeFromSuperview];
            [self.scrollView addSubview:self.footerView];
        }
        self.footerView.frame = CGRectMake(0, self.scrollView.contentSize.height, self.scrollView.fsW, self.footerView.fsH);
    }
    
}


#pragma mark UIScrollView Delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!self.userScrolling) return;
    
    if (self.headerState == AwfulPullForActionStateLoading || 
        self.footerState == AwfulPullForActionStateLoading)
        return;
    
    
    CGFloat scrollAmount = scrollView.contentOffset.y;
    
    CGFloat headerThreshhold = -2*self.headerView.fsH - EXTRA_PULL_THRESHHOLD;
    
    int lastPageChange = self.delegate.isOnLastPage? self.footerView.fsH : 0;
    CGFloat footerThreshhold = self.scrollView.contentSize.height - self.scrollView.fsH + 2*self.footerView.fsH + EXTRA_PULL_THRESHHOLD + lastPageChange;
    
    if (self.footerView.foY != scrollView.contentSize.height) {
        self.footerView.foY = scrollView.contentSize.height;
    }
    
    if ([self.footerView respondsToSelector:@selector(scrollViewDidScroll:)])
        [self.footerView scrollViewDidScroll:self.scrollView];
    
    if ([self.headerView respondsToSelector:@selector(scrollViewDidScroll:)])
        [self.headerView scrollViewDidScroll:self.scrollView];
    
    
    //Normal State
    if (scrollAmount >= 0 && scrollAmount <= scrollView.contentSize.height - scrollView.fsH) {
        //NSLog(@"normal");
        self.headerState = AwfulPullForActionStateNormal;
        self.footerState = AwfulPullForActionStateNormal;
		//scrollView.contentInset = UIEdgeInsetsZero;
        return;
    }
    
    //Header Pulling
    if (scrollAmount < 0 && scrollAmount >= headerThreshhold) {
        //NSLog(@"header pull");
        self.headerState = AwfulPullForActionStatePulling;
        return;
    }
    
    
    //Footer Pulling
    if (scrollAmount > self.scrollView.contentSize.height - 
        self.scrollView.fsH + 
        (self.delegate.isOnLastPage? self.footerView.fsH : 0 )
        && scrollAmount <= footerThreshhold) {
        //NSLog(@"footer pull");
        self.footerState = AwfulPullForActionStatePulling;
        return;
    }
    
    
    
    //Header Loading
    if (scrollAmount < headerThreshhold) {
        //NSLog(@"header load");
        self.headerState = AwfulPullForActionStateLoading;
        return;
    }
    
    
    //Footer Loading
    if (scrollAmount > footerThreshhold) {
        //NSLog(@"footer load");
        self.footerState = AwfulPullForActionStateLoading;
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(scrollViewDidScroll:)])
        [self.delegate scrollViewDidScroll:scrollView];
}

-(void) scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.userScrolling = YES;
}

-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate 
{
    self.userScrolling = NO;

    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)])
        [self.delegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

#pragma mark Swipe to Cancel
-(void) setSwipeCanCancel:(UIView<AwfulPullForActionViewDelegate>*)view {
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(didSwipeToCancel:)
                                       ];
    
    swipe.numberOfTouchesRequired = 1;
    swipe.direction = (UISwipeGestureRecognizerDirectionLeft);
    [view addGestureRecognizer:swipe];
    //NSLog(@"added swipe %@ to view %@", swipe, view);
}

    
-(void) didSwipeToCancel:(UISwipeGestureRecognizer*)swipe {
    //NSLog(@"swipe cancel %@, view %@", swipe, swipe.view);
    
    UIView<AwfulPullForActionViewDelegate>* view = (UIView<AwfulPullForActionViewDelegate>*)(swipe.view);
    
    [self.delegate didCancelPullForAction:self];
    //animate view off screen to the left, following swipe direction
    [UIView animateWithDuration:.2
                     animations:^{
                         view.foX -= view.fsW;
                     } 
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:.2
                                          animations:^{
                                              self.scrollView.contentInset = UIEdgeInsetsZero;
                                          }
                          completion:^(BOOL finished) {
                              view.foX = 0;
                          }
                          ];
                     }
         
     ];
    [swipe.view removeGestureRecognizer:swipe];
}

#pragma mark auto reload
-(void) didSwitchAutoF5:(UISwitch *)switchObj {
    if (switchObj.on) {
        self.autoRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:20 
                                                                 target:self
                                                               selector:@selector(timerDidFire:)
                                                               userInfo:nil
                                                                repeats:YES];
    }   
    else {
        [self.autoRefreshTimer invalidate];
        self.autoRefreshTimer = nil;
    }
}


-(void) timerDidFire:(NSTimer*)timer {
    NSLog(@"timer fired");
    [(AwfulPage*)self.delegate refresh];
}

#pragma mark Properties
-(void) setFooterState:(AwfulPullForActionState)state {
    if (self.footerView.state == state) return;
    self.footerView.state = state;
    
    //if loading, set inset and scroll
    if (state == AwfulPullForActionStateLoading) {
        [self setSwipeCanCancel:self.footerView];
        UIEdgeInsets inset = UIEdgeInsetsMake(0.0f, 0.0f, self.footerView.fsH, 0.0f);
        self.scrollViewInset = inset;
        [self.delegate didPullFooter:self.footerView];
    }
    
    if (self.delegate.isOnLastPage) {
        UIEdgeInsets inset = UIEdgeInsetsMake(0.0f, 0.0f, self.footerView.fsH, 0.0f);
        self.scrollViewInset = inset;
    }
}

-(void) setHeaderState:(AwfulPullForActionState)state {
    self.headerView.state = state;
    
    if (self.headerState == AwfulPullForActionStateLoading) {
        [self setSwipeCanCancel:self.headerView];
        UIEdgeInsets inset = UIEdgeInsetsMake(self.headerView.fsH, 0.0f, 0.0f, 0.0f);
        self.scrollViewInset = inset;
        [self.delegate didPullHeader:self.headerView];
    }
}

-(void) setScrollViewInset:(UIEdgeInsets)inset {
    
    self.scrollView.userInteractionEnabled = NO;
    [UIView animateWithDuration:.2 
                     animations:^{
                         self.scrollView.contentInset = inset;
                     }
                     completion:^(BOOL finished) {
                         self.scrollView.userInteractionEnabled = YES;
                     }
     ];

}

-(AwfulPullForActionState) footerState {
    return self.footerView.state;
}

-(AwfulPullForActionState) headerState {
    return self.headerView.state;
}

@end
