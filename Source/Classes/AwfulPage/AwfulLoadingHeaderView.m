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
            self.lastUpdatedLabel.text = [NSString stringWithFormat:@"Updated %@", 
                                          self.stringTimeIntervalSinceLoad];
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
@end
