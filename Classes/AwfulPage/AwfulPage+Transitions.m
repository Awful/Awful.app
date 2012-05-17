//
//  AwfulPage+Transitions.m
//  Awful
//
//  Created by me on 5/15/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage+Transitions.h"

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
    NSLog(@"refresh transition");
    
    self.nextPageWebView.frame = self.webView.frame;
    self.nextPageWebView.scrollView.contentOffset = self.webView.scrollView.contentOffset;
    //[self.webView removeFromSuperview];
    
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
    
    [UIView animateWithDuration:.5 
                          delay:0 
                        options:(UIViewAnimationOptionCurveEaseIn) 
                     animations:^{
                         self.nextPageWebView.frame = self.webView.frame;
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
                        options:(UIViewAnimationOptionCurveEaseIn) 
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
    [self.webView removeFromSuperview];
    self.webView = self.nextPageWebView;
    self.pullForActionController.scrollView = self.webView.scrollView;
    //self.pullToNavigateView.onLastPage = YES;
    self.pullForActionController.scrollView = self.webView.scrollView;
    
    self.nextPageWebView = [JSBridgeWebView new];
    self.nextPageWebView.frame = self.webView.frame;
    self.nextPageWebView.foY = self.nextPageWebView.fsH;
    self.nextPageWebView.delegate = self;
    [self.view addSubview:self.nextPageWebView];
}
@end
