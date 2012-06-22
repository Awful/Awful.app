//
//  AwfulPullForActionController.m
//  Awful
//
//  Created by me on 5/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPullForActionController.h"

#define EXTRA_PULL_THRESHHOLD 5

@implementation AwfulPullForActionController
@synthesize scrollView = _scrollView;
@synthesize headerView = _headerView;
@synthesize footerView = _footerView;
@synthesize delegate = _delegate;
@synthesize userScrolling = _userScrolling;

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
    CGFloat footerThreshhold = self.scrollView.contentSize.height - self.scrollView.fsH + 2*self.footerView.fsH + EXTRA_PULL_THRESHHOLD;
    
    //check footer positioning, it got misplaced sometimes for some reason
    if (self.footerView.foY != scrollView.contentSize.height) {
        self.footerView.foY = scrollView.contentSize.height;
    }
    
    
    
    //Normal State
    if (scrollAmount >= 0 && scrollAmount <= scrollView.contentSize.height - scrollView.fsH) {
        NSLog(@"normal");
        self.headerState = AwfulPullForActionStateNormal;
        self.footerState = AwfulPullForActionStateNormal;
		//scrollView.contentInset = UIEdgeInsetsZero;
        return;
    }
    
    //Header Pulling
    if (scrollAmount < 0 && scrollAmount >= headerThreshhold) {
        NSLog(@"header pull");
        self.headerState = AwfulPullForActionStatePulling;
        return;
    }
    
    
    //Footer Pulling
    if (scrollAmount > self.scrollView.contentSize.height - self.scrollView.fsH && scrollAmount <= footerThreshhold) {
        NSLog(@"footer pull");
        self.footerState = AwfulPullForActionStatePulling;
        return;
    }
    
    
    
    //Header Loading
    if (scrollAmount < headerThreshhold) {
        NSLog(@"header release");
        self.headerState = AwfulPullForActionStateRelease;
        return;
    }
    
    
    //Footer Loading
    if (scrollAmount > footerThreshhold) {
        NSLog(@"footer release");
        self.footerState = AwfulPullForActionStateRelease;

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
    CGFloat scrollAmount = scrollView.contentOffset.y;
    
    CGFloat headerThreshhold = -2*self.headerView.fsH - EXTRA_PULL_THRESHHOLD;
    CGFloat footerThreshhold = scrollView.contentSize.height - scrollView.fsH + 2*self.footerView.fsH + EXTRA_PULL_THRESHHOLD;
    
    UIEdgeInsets inset;
    if (scrollAmount < headerThreshhold) {
        self.headerState = AwfulPullForActionStateLoading;
        [self setSwipeCanCancel:self.headerView];
		inset = UIEdgeInsetsMake(self.headerView.fsH, 0.0f, 0.0f, 0.0f);
        [self.delegate didPullHeader:self.headerView];
    }
    
    else if (scrollAmount > footerThreshhold) {
        self.footerState = AwfulPullForActionStateLoading;
        [self setSwipeCanCancel:self.footerView];
		inset = UIEdgeInsetsMake(0.0f, 0.0f, self.footerView.fsH, 0.0f);
        [self.delegate didPullFooter:self.footerView];
    }
    else 
        return;
    
    [UIView animateWithDuration:.2 animations:^{
		self.scrollView.contentInset = inset;
    }
     ];

    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)])
        [self.delegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

-(void) setSwipeCanCancel:(UIView<AwfulPullForActionViewDelegate>*)view {
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(didSwipeToCancel:)
                                           ];
        
        swipe.numberOfTouchesRequired = 1;
        swipe.direction = (UISwipeGestureRecognizerDirectionLeft);
        [view addGestureRecognizer:swipe];
}
    
-(void) didSwipeToCancel:(UISwipeGestureRecognizer*)swipe {
    //NSLog(@"cancel");
    [swipe.view removeGestureRecognizer:swipe];
    [self.delegate didCancelPullForAction:self];
    
    //remove inset, scroll if necessary
    [UIView animateWithDuration:.2
                     animations:^{
                         self.scrollView.contentInset = UIEdgeInsetsZero;
                     }
     ];
}

-(void) setFooterState:(AwfulPullForActionState)state {
    self.footerView.state = state;
    
    //if loading, set inset and scroll
    if (state == AwfulPullForActionStateLoading)
        [self.scrollView setContentOffset:CGPointMake(0,self.scrollView.contentSize.height-
                                                      self.scrollView.fsH+
                                                      self.footerView.fsH) 
                                 animated:YES];
    
    //otherwise remove inset, maybe scroll?
    //might not be necessary since webview is getting replaced
}

-(void) setHeaderState:(AwfulPullForActionState)state {
    self.headerView.state = state;
    
    //set inset, scroll to top to show
    if (self.headerState == AwfulPullForActionStateLoading)
        [self.scrollView setContentOffset:CGPointMake(0,-self.footerView.fsH) 
                                 animated:YES];
    
    //clear inset
}

-(AwfulPullForActionState) footerState {
    return self.footerView.state;
}

-(AwfulPullForActionState) headerState {
    return self.headerView.state;
}

@end
