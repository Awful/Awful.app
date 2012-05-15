//
//  AwfulPullToNavigateView.m
//  Awful
//
//  Created by me on 5/10/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "AwfulLoadingFooterView.h"
#import "AwfulPage.h"

#define FLIP_ANIMATION_DURATION 0.18f

@implementation AwfulLoadingFooterView
@synthesize state = _state;
@synthesize onLastPage = _onLastPage;
@synthesize scrollView = _scrollView;
@synthesize autoF5 = _autoF5;

-(id) init {
    self = [super initWithFrame:CGRectMake(0, 0, 768, 65)];
    self.autoF5 = [[UISwitch alloc] initWithFrame:CGRectMake(self.fsW - 100,0 , 0, 0)];
    self.autoF5.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|
                                    UIViewAutoresizingFlexibleTopMargin|
                                    UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.autoF5];
    
    self.onLastPage = YES;
    self.backgroundColor = [UIColor clearColor];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.bounds;
    gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor blackColor] CGColor], 
                       (id)[[UIColor colorWithRed:.09 green:.24 blue:.40 alpha:1] CGColor], 
                       nil];
    [self.layer insertSublayer:gradient atIndex:0];
    
    return self;
}

-(void) setOnLastPage:(BOOL)onLastPage {
    _onLastPage = onLastPage;
    
    if (onLastPage) {
        self.autoF5.hidden = NO;
    }
    
    else {
        //self.autoF5.hidden = YES;
        
    }
    
    
}



- (void)setState:(AwfulPullForActionState)aState
{
	_state = aState;
	switch (aState) {
		case AwfulPullForActionStateRelease:
			
			self.statusLabel.text = @"Release for next page...";
			[CATransaction begin];
			[CATransaction setAnimationDuration:FLIP_ANIMATION_DURATION];
			self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 180.0f, 0.0f, 0.0f, 1.0f);
			[CATransaction commit];
			
			break;
		case AwfulPullForActionStateNormal:
        case AwfulPullForActionStatePulling:
            if (!self.onLastPage) {
                if (self.state == EGOOPullRefreshPulling) {
                    [CATransaction begin];
                    [CATransaction setAnimationDuration:FLIP_ANIMATION_DURATION];
                    self.arrowImage.transform = CATransform3DIdentity;
                    [CATransaction commit];
                }
                
                self.statusLabel.text = (@"Pull up for next page...");
                [self.activityView stopAnimating];
                [CATransaction begin];
                [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions]; 
                self.arrowImage.hidden = NO;
                self.arrowImage.transform = CATransform3DIdentity;
                [CATransaction commit];
                
                [self refreshLastUpdatedDate];
            }
            else {
                self.statusLabel.text = @"End of the Thread";
                self.autoF5.hidden = NO;
            }
            
            
			break;
		case AwfulPullForActionStateLoading:
			
			self.statusLabel.text = @"Loading...";
			[self.activityView startAnimating];
			[CATransaction begin];
			[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions]; 
			self.arrowImage.hidden = YES;
			[CATransaction commit];
			
			break;
		default:
			break;
	}
    
}

@end
