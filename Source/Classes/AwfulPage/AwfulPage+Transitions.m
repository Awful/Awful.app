//
//  AwfulPage+Transitions.m
//  Awful
//
//  Created by me on 5/15/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage+Transitions.h"
#import "AwfulRefreshControl.h"
#import "AwfulLoadNextControl.h"
#import "AwfulLastPageControl.h"

@implementation AwfulPage (Transitions)

-(void) doPageTransition {
    //page number stored in webview tags
    //compare numbers, determine animation
    int diff = self.nextPageWebView.tag - self.webView.tag;
    
    if (diff == 0) //refresh
        [self reloadTransition];

    else if (diff > 0)
        [self pageForwardTransition];
    
    else if (diff < 0)
        [self pageBackTransition];

    
}

-(void) reloadTransition {
    //next page below original
    //hide original
    //scroll next page up a little?
    NSLog(@"page refresh transition");
    
    self.nextPageWebView.frame = self.webView.frame;
    self.nextPageWebView.scrollView.contentOffset = self.webView.scrollView.contentOffset;
    
    [self performSelector:@selector(reloadTransition2) withObject:nil afterDelay:0.0];
}
-(void) reloadTransition2 {
    [self.webView removeFromSuperview];
    
    CGFloat pageLengthIncrease = self.nextPageWebView.scrollView.contentSize.height - self.webView.scrollView.contentSize.height;
    CGFloat amountToScroll;
    if (pageLengthIncrease > self.nextPageWebView.fsH)
        amountToScroll = self.nextPageWebView.fsH - 100;
    else
        amountToScroll = pageLengthIncrease;
    
    [self.nextPageWebView.scrollView setContentOffset:CGPointMake(0, self.nextPageWebView.scrollView.contentOffset.y + amountToScroll)
                                             animated:YES
     ];
    
    [self didFinishPageTransition];
    
    //CGPoint offset = self.webView.scrollView.contentOffset;
    //offset.y = MIN(offset.y + 350, self.webView.scrollView.contentSize.height);
    
    
    //[self.webView.scrollView setContentOffset:offset
    //                                         animated:YES];    
    
    //self.pullForActionController.scrollView = self.webView.scrollView;
}

-(void) pageForwardTransition {
    //position next page below current
    //move both up
    
    self.nextPageWebView.frame = self.webView.frame;
    self.nextPageWebView.foY = self.nextPageWebView.fsH;
    //self.nextPageWebView.hidden = YES;
    
    CGPoint bottomOffset = CGPointMake(0, self.webView.scrollView.contentSize.height - self.webView.scrollView.bounds.size.height + self.loadNextPageControl.fsH);
    [self.webView.scrollView setContentOffset:bottomOffset animated:YES];
    
    [UIView animateWithDuration:.5 
                          delay:0 
                        options:(UIViewAnimationOptionCurveEaseInOut) 
                     animations:^{
                         self.nextPageWebView.foY = 0;
                         self.webView.foY = -self.webView.fsH;
                     }
                     completion:^(BOOL finished) {
                         [self didFinishPageTransition];
                     }
     ];
}


-(void) pageBackTransition {
    //position next page above current
    //move both down
    
    self.nextPageWebView.frame = self.webView.frame;
    self.nextPageWebView.foY = -self.nextPageWebView.fsH;
    
    [UIView animateWithDuration:.5 
                          delay:0 
                        options:(UIViewAnimationOptionCurveEaseInOut) 
                     animations:^{
                         self.nextPageWebView.frame = self.webView.frame;
                         self.webView.foY = self.webView.fsH;
                     }
                     completion:^(BOOL finished) {
                         [self didFinishPageTransition];
                     }
     ];
}

-(void) didFinishPageTransition {
    if(self.webView.foY == 0  && self.nextPageWebView.foY != 0) {
        NSLog(@"BUG: tried to remove visible webview");
        return;
    }
    [self.webView removeFromSuperview];
    self.webView = self.nextPageWebView;
    self.webView.scrollView.scrollsToTop = YES;
    
    [self.awfulRefreshControl removeFromSuperview];
    [self.webView.scrollView addSubview:self.awfulRefreshControl];
    
    
    [self.loadNextPageControl removeFromSuperview];
    
    if (self.webView.tag == self.numberOfPages && [self.loadNextPageControl isMemberOfClass:[AwfulLoadNextControl class]]) {
        self.loadNextPageControl = [[AwfulLastPageControl alloc] initWithFrame:self.loadNextPageControl.frame];
        self.loadNextPageControl.changeInsetToShow = YES;
    }
    else if (self.webView.tag < self.numberOfPages && [self.loadNextPageControl isMemberOfClass:[AwfulLastPageControl class]]) {
        self.loadNextPageControl = [[AwfulLoadNextControl alloc] initWithFrame:self.loadNextPageControl.frame];
        self.loadNextPageControl.changeInsetToShow = NO;
    }
    
    self.loadNextPageControl.foY = self.webView.scrollView.contentSize.height;
    
    [self.webView.scrollView addSubview:self.loadNextPageControl];
    

    
    self.nextPageWebView = [UIWebView new];
    self.nextPageWebView.frame = self.webView.frame;
    self.nextPageWebView.foY = self.nextPageWebView.fsH;
    self.nextPageWebView.delegate = self;
    self.nextPageWebView.scrollView.scrollsToTop = NO;
    [self.view addSubview:self.nextPageWebView];
}
@end
