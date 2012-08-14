//
//  AwfulPage+Scrolling.m
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage+Scrolling.h"
#import "AwfulRefreshControl.h"
#import "AwfulLoadNextControl.h"

@implementation AwfulPage (Scrolling)
#pragma mark ScrollView Delegate
-(void) scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.awfulRefreshControl) {
        self.awfulRefreshControl.userScrolling = YES;
    }
    
    if (self.loadNextPageControl)
        self.loadNextPageControl.userScrolling = YES;
    
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (self.awfulRefreshControl && self.awfulRefreshControl.userScrolling) {
        [self.awfulRefreshControl didScrollInScrollView:scrollView];
    }
    
    if (self.loadNextPageControl && self.loadNextPageControl.userScrolling)
        [self.loadNextPageControl didScrollInScrollView:scrollView];
    
    self.isHidingToolbars = NO;
    
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.awfulRefreshControl) {
        self.awfulRefreshControl.userScrolling = NO;
    }
    
    if (self.loadNextPageControl)
        self.loadNextPageControl.userScrolling = NO;
    
}

-(void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    //self.isHidingToolbars = NO;
    self.loadNextPageControl.state = AwfulRefreshControlStateNormal;
    
    self.isHidingToolbars = YES;
}

#pragma mark Web page scrolling
-(void)scrollToBottom
{
    [self.webView stringByEvaluatingJavaScriptFromString:@"window.scrollTo(0, document.body.scrollHeight);"];
}

-(void)scrollToSpecifiedPost
{
    [self scrollToPost:self.postIDScrollDestination];
}

-(void)scrollToPost : (NSString *)post_id
{
    if(post_id != nil) {
        NSString *scrolling = [NSString stringWithFormat:@"scrollToID('%@')", post_id];
        [self.webView stringByEvaluatingJavaScriptFromString:scrolling];
    }
}


@end
