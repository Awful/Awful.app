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


#pragma mark UIScrollView Delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat scrollAmount = scrollView.contentOffset.y;
    
    CGFloat headerThreshhold = -self.headerView.fsH - 5.0f;
    CGFloat footerThreshhold = self.scrollView.contentSize.height - self.scrollView.fsH + self.footerView.fsH + 5.0f;
    
	//NSLog(@"Scrollview offset:%f vs contentsize:%f", scrollAmount, threshhold);
    
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
        NSLog(@"header load");
        self.headerView.state = AwfulPullForActionStateLoading;
        return;
    }
    
    
    //Footer Loading
    if (scrollAmount > footerThreshhold) {
        NSLog(@"footer load");
        self.footerView.state = AwfulPullForActionStateLoading;
		scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, self.footerView.fsH, 0.0f);
        [self.delegate didPullFooter];
        return;
    }
    
    [self.delegate scrollViewDidScroll:scrollView];
}

-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate 
{
    CGFloat scrollAmount = scrollView.contentOffset.y;
    
    CGFloat headerThreshhold = -self.headerView.fsH - 5.0f;
    CGFloat footerThreshhold = self.scrollView.contentSize.height + self.footerView.fsH + 5.0f;
    
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
    
    [UIView animateWithDuration:.2 animations:^{
		self.scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 60.0f, 0.0f);
    }
     ];

	[self.delegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}




@end
