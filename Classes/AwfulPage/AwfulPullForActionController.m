//
//  AwfulPullForActionController.m
//  Awful
//
//  Created by me on 5/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPullForActionController.h"

@implementation AwfulPullForActionController
@synthesize scrollView = _scrollView;
@synthesize headerView = _headerView;
@synthesize footerView = _footerView;
@synthesize delegate = _delegate;

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
    if (self.headerView.state == AwfulPullForActionStateLoading || 
        self.footerView.state == AwfulPullForActionStateLoading)
        return;
    
    CGFloat scrollAmount = scrollView.contentOffset.y;
    
    CGFloat headerThreshhold = -self.headerView.fsH - 5.0f;
    CGFloat footerThreshhold = self.scrollView.contentSize.height - self.scrollView.fsH + self.footerView.fsH + 5.0f;
    
    //check footer positioning, it got misplaced sometimes for some reason
    if (self.footerView.foY != scrollView.contentSize.height) {
        self.footerView.foY = scrollView.contentSize.height;
    }
    
    
    
    //Normal State
    if (scrollAmount >= 0 && scrollAmount <= scrollView.contentSize.height - scrollView.fsH) {
        NSLog(@"normal");
        self.headerView.state = AwfulPullForActionStateNormal;
        self.footerView.state = AwfulPullForActionStateNormal;
		scrollView.contentInset = UIEdgeInsetsZero;
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

-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate 
{
    CGFloat scrollAmount = scrollView.contentOffset.y;
    
    CGFloat headerThreshhold = -self.headerView.fsH - 5.0f;
    CGFloat footerThreshhold = scrollView.contentSize.height - scrollView.fsH + self.footerView.fsH + 5.0f;
    
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
