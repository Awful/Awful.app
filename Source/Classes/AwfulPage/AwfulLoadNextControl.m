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
    return self;
}

-(void) didScrollInScrollView:(UIScrollView *)scrollView {
    CGFloat scrollAmount = scrollView.contentOffset.y + scrollView.fsH;
    CGFloat limit = scrollView.contentSize.height + self.fsH;
    CGFloat threshhold = limit + 2.25*self.fsH;
    
    //gets mispositioned somethimes, check that
    if (self.foY != scrollView.contentSize.height) {
        self.foY = scrollView.contentSize.height;
        self.hidden = NO;
    }
    
    if (scrollAmount < limit && self.state == AwfulRefreshControlStateNormal) return;
    
    
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


-(void) setState:(AwfulRefreshControlState)state {
    if (self.state == state && 
        state != AwfulRefreshControlStateLoading &&
        [[NSDate date] timeIntervalSinceDate:self.loadedDate] < 60)
        return;
    
    
    switch (state) {
        case AwfulRefreshControlStateLoading:
            self.title.text = @"Loading next page...";
            self.subtitle.text = @"Swipe left to cancel";
            self.imageView.hidden = YES;
            [self.activityView startAnimating];
            break;
            
        case AwfulRefreshControlStatePulling:
            self.title.text = @"Keep pulling for next page";
            self.subtitle.text = nil;
            self.imageView.hidden = NO;
            [self.activityView stopAnimating];
            break;
            
        case AwfulRefreshControlStateNormal:
            self.title.text = @"Pull for next page...";
            self.subtitle.text = nil;
            self.imageView.hidden = NO;
            [self.activityView stopAnimating];
            break;
    }
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    
}


@end
