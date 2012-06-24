//
//  AwfulLoadingHeaderView.m
//  Awful
//
//  Created by me on 6/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoadingHeaderView.h"

@implementation AwfulLoadingHeaderView
@synthesize loadedDate = _loadedDate;

-(void) setState:(AwfulPullForActionState)state {
    [super setState:state];
    
    switch (state) {
        case AwfulPullForActionStateLoading:
            self.lastUpdatedLabel.text = @"Swipe left to cancel";
            break;
            
        default:
            self.lastUpdatedLabel.text = [NSString stringWithFormat:@"Updated: %@", self.loadedDate];
    }
    
}

-(void) setLoadedDate:(NSDate *)loadedDate {
    _loadedDate = loadedDate;
    self.lastUpdatedLabel.text = [NSString stringWithFormat:@"Updated: %@", self.loadedDate];
}
@end
