//
//  AwfulLoadingHeaderView.m
//  Awful
//
//  Created by me on 6/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoadingHeaderView.h"
#import "SRRefreshView.h"
#import <QuartzCore/QuartzCore.h>

@implementation AwfulLoadingHeaderView
@synthesize loadedDate = _loadedDate;
@synthesize test = _test;

-(void) setState:(AwfulPullForActionState)state {
    if (self.state == state) return;
    [super setState:state];
    
    switch (state) {
        case AwfulPullForActionStateLoading:
            self.lastUpdatedLabel.text = @"Swipe left to cancel";
            break;
            
        default:
            self.lastUpdatedLabel.text = [NSString stringWithFormat:@"Updated %@", 
                                          self.stringTimeIntervalSinceLoad];
    }
    
    if (!self.test) {
    //self.test = [[SRRefreshView alloc] initWithFrame:CGRectMake(50,20,50,50)];
        //[self addSubview:self.test];
    //self.test.delegate = self;
    //self.test.scrollView = _scrollView;
        //[self.arrowImage removeFromSuperlayer];
    }
}

-(NSString*) stringTimeIntervalSinceLoad {
    NSTimeInterval s = [[NSDate date] timeIntervalSinceDate:self.loadedDate];
    int m = (int)s/60;
    if (m == 0)
        return @"less than a minute ago";
    else if (m < 50)
        return [NSString stringWithFormat:@"%i minute%@ ago", m, (m==1)? @"" : @"s"];
    else if (m >= 50 && m <= 70)
        return @"about an hour ago";
    else
        return @"over an hour ago";
    
    return @"???";
}

/*
 -(void) scrollViewDidScroll:(UIScrollView*)scrollView {
 //UIScrollView *scrollView = ((AwfulPullForActionController*)msg.object).scrollView;
 double scrollAmount = scrollView.contentOffset.y;
 double threshhold = -2.5*self.fsH;
 
 //NSLog(@"header scroll");
 
 }
 
 -(void) scrollViewDidEndDragging:(UIScrollView*)scrollView {
 
 }
 */
@end
