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
    
    if (self.headerView.state == AwfulPullForActionStateLoading || 
        self.footerView.state == AwfulPullForActionStateLoading)
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
        self.headerView.state = AwfulPullForActionStateNormal;
        self.footerView.state = AwfulPullForActionStateNormal;
		//scrollView.contentInset = UIEdgeInsetsZero;
        return;
    }
    
    //Header Pulling
    if (scrollAmount < 0 && scrollAmount >= headerThreshhold) {
        NSLog(@"header pull");
        self.headerView.state = AwfulPullForActionStatePulling;
        return;
    }
    
    
    //Footer Pulling
    if (scrollAmount > self.scrollView.contentSize.height - self.scrollView.fsH && scrollAmount <= footerThreshhold) {
        NSLog(@"footer pull");
        self.footerView.state = AwfulPullForActionStatePulling;
        return;
    }
    
    
    
    //Header Loading
    if (scrollAmount < headerThreshhold) {
        NSLog(@"header release");
        self.headerView.state = AwfulPullForActionStateRelease;
        return;
    }
    
    
    //Footer Loading
    if (scrollAmount > footerThreshhold) {
        NSLog(@"footer release");
        self.footerView.state = AwfulPullForActionStateRelease;

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
        self.headerView.state = AwfulPullForActionStateLoading;
		inset = UIEdgeInsetsMake(self.headerView.fsH, 0.0f, 0.0f, 0.0f);
        [self.delegate didPullHeader];
    }
    
    else if (scrollAmount > footerThreshhold) {
        self.footerView.state = AwfulPullForActionStateLoading;
		inset = UIEdgeInsetsMake(0.0f, 0.0f, self.footerView.fsH, 0.0f);
        [self.delegate didPullFooter];
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




@end
