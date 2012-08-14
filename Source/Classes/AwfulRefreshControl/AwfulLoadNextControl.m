//
//  AwfulLoadNextControl.m
//  Awful
//
//  Created by me on 6/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoadNextControl.h"

@implementation AwfulLoadNextControl

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.hidden = YES;
    self.imageView2.hidden = YES;
    return self;
}

-(void) didScrollInScrollView:(UIScrollView *)scrollView {
    CGFloat scrollAmount = scrollView.contentOffset.y + scrollView.fsH;
    CGFloat limit = scrollView.contentSize.height + self.fsH;
    CGFloat threshhold = limit + 1.5*self.fsH;
    
    //gets mispositioned somethimes, check that
    if (self.foY != scrollView.contentSize.height) {
        self.foY = scrollView.contentSize.height;
        self.hidden = NO;
    }
    
    if (scrollAmount < limit && self.state == AwfulRefreshControlStateNormal) return;
    
    //image for refresh control
    //Using 2 images on top of each other
    //scrollamount changes the width of the top image from 0-100%
    CGFloat imagePct = (scrollAmount - limit)/(threshhold - limit);
    imagePct = imagePct < 0? 0 : imagePct;
    imagePct = imagePct > 1? 1 : imagePct;
    self.imageView2.foX = self.imageView.foX + self.imageView.fsW - (self.imageView.fsW * imagePct);
    self.imageView2.fsW = self.imageView.fsW * imagePct;
    
    
    //normal
    if (scrollAmount <= limit) {
        self.state = AwfulRefreshControlStateNormal;
        return;
    }
    
    //Header Pulling
    if (scrollAmount > limit && scrollAmount <= threshhold) {
        self.state = AwfulRefreshControlStatePulling;
        return;
    }    
    
    //Header Loading
    if (scrollAmount > threshhold) {
        self.state = AwfulRefreshControlStateLoading;
        //[scrollView setContentOffset:CGPointMake(0, -self.fsH) animated:YES];
        return;
    }
}

/*
-(void) setState:(AwfulRefreshControlState)state {
    if (self.state == state && 
        state != AwfulRefreshControlStateLoading &&
        [[NSDate date] timeIntervalSinceDate:self.loadedDate] < 60)
        return;
    
    _state = state;
    
    switch (state) {
        case AwfulRefreshControlStateLoading:
            self.title.text = @"Loading next page...";
            self.subtitle.text = @"Swipe left to cancel";
            self.imageView.hidden = YES;
            self.imageView2.hidden = YES;
            [self.activityView startAnimating];
            self.changeInsetToShow = YES;
            break;
            
        case AwfulRefreshControlStatePulling:
            self.title.text = @"Keep pulling for next page";
            self.subtitle.text = nil;
            self.imageView.hidden = NO;
            self.changeInsetToShow = NO;
            [self.activityView stopAnimating];
            break;
            
        case AwfulRefreshControlStateNormal:
            self.title.text = @"Pull for next page...";
            self.subtitle.text = nil;
            self.imageView.hidden = NO;
            self.changeInsetToShow = NO;
            [self.activityView stopAnimating];
            break;
    }
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    
}*/


-(void) changeLabelTextForCurrentState {
    //webview's tag is the current page
    //this control is in the scrollview of the webview
    NSInteger currentPage = self.superview.superview.tag;
    
    switch (self.state) {
        case AwfulRefreshControlStateLoading:
            self.title.text = [NSString stringWithFormat:@"Loading page %i", self.nextPageNumber];
            self.subtitle.text = @"Swipe left to cancel";
            break;
            
        case AwfulRefreshControlStatePulling:
            self.title.text = [NSString stringWithFormat:@"Keep pulling for page %i", currentPage+1];
            self.subtitle.text = nil;
            break;
            
        case AwfulRefreshControlStateNormal:
            self.title.text = [NSString stringWithFormat:@"End of page %i", currentPage];
            self.subtitle.text = @"Pull up for next page";
            break;
            
        case AwfulRefreshControlStateParsing:
            self.title.text = [NSString stringWithFormat:@"Formatting page %i", currentPage+1];
            break;
            
        case AwfulRefreshControlStatePageTransition:
            self.title.text = [NSString stringWithFormat:@"Leaving page %i", currentPage];
            self.imageView.image = [UIImage imageNamed:@"emot-byewhore.gif"];
            self.imageView2.hidden = YES;
            break;
    }
}


-(void) setChangeInsetToShow:(BOOL)show {
    CGFloat inset = show? self.fsH : 0;
    
    UIScrollView* scrollView = (UIScrollView*)self.superview;
    UIEdgeInsets insets = scrollView.contentInset;
    if (inset == insets.bottom) return;
    insets.bottom = inset;
    
    if (show) {
        scrollView.userInteractionEnabled = NO;
        [UIView animateWithDuration:.3
                         animations:^{
                             
                             scrollView.contentInset = insets;
                         }
                         completion:^(BOOL finished) {
                             scrollView.userInteractionEnabled = YES;
                         }
         ];
    }
}

@end
