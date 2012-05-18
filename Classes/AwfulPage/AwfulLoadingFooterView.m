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
@synthesize activityView = _activityView;

-(id) init {
    //self = [super initWithFrame:CGRectMake(0, 0, 768, 65)];
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"PullToNavCell"];
    self.frame = CGRectMake(0, 0, 300, 60);
    
    UIView *accessory = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
    self.autoF5 = [[UISwitch alloc] initWithFrame:CGRectMake(0, 15, 100, 0)];
    self.autoF5.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    UILabel *autoF5Label = [UILabel new];
    autoF5Label.text = @"Auto-Refresh";
    autoF5Label.textColor = [UIColor lightGrayColor];
    autoF5Label.shadowColor = [UIColor blackColor];
    autoF5Label.backgroundColor = [UIColor clearColor];
    autoF5Label.font = [UIFont systemFontOfSize:11];
    autoF5Label.frame = CGRectMake(0, 45, accessory.fsW, 15);
    autoF5Label.textAlignment = UITextAlignmentCenter;
    
    [accessory addSubview:self.autoF5];
    [accessory addSubview:autoF5Label];
    self.accessoryView = accessory;
    
    self.imageView.image = [UIImage imageNamed:@"whiteArrow.png"];
    self.imageView.contentMode = UIViewContentModeCenter;
    
    self.onLastPage = NO;
    self.backgroundColor = [UIColor clearColor];
        
    self.textLabel.text = @"Release for next page...";
    self.textLabel.textColor = [UIColor whiteColor];
    self.textLabel.shadowColor = [UIColor blackColor];
    
    self.detailTextLabel.text = @"Go to page X of Y";
    self.detailTextLabel.textColor = [UIColor whiteColor];
    
    self.indentationLevel = 2;
    
    
    self.activityView = [UIActivityIndicatorView new];
    self.activityView.hidesWhenStopped = YES;
    [self addSubview:self.activityView];
    
    return self;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.activityView.frame = self.imageView.frame;
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.bounds;
    gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor blackColor] CGColor], 
                       (id)[[UIColor colorWithRed:.09 green:.24 blue:.40 alpha:1] CGColor], 
                       nil];
    [self.layer insertSublayer:gradient atIndex:0];
    

}

-(void) setOnLastPage:(BOOL)onLastPage {
    _onLastPage = onLastPage;
    
    if (onLastPage) {
        self.accessoryView.hidden = NO;
    }
    
    else {
        self.accessoryView.hidden = YES;
        
    }
    
    
}



- (void)setState:(AwfulPullForActionState)aState
{
	_state = aState;
    int onLastPage = self.onLastPage? AwfulPullForActionOnLastPage : 0;
    
	switch (aState + onLastPage) {
		case AwfulPullForActionStateRelease:
			
			self.textLabel.text = @"Release for next page...";
            self.detailTextLabel.text = @"Pull down to cancel";
            //[UIView animateWithDuration:.3
            //                 animations:^{
                                 self.imageView.transform = CGAffineTransformMakeRotation(0);
             //                }
             //];
			
			break;
            
                        
		case AwfulPullForActionStateLoading:
			self.textLabel.text = @"Loading...";
            self.detailTextLabel.text = nil;
            self.imageView.hidden = YES;
			[self.activityView startAnimating];
			return;
			break;
            
		case AwfulPullForActionStateNormal:
        case AwfulPullForActionStatePulling:
            self.textLabel.text = (@"Pull up for next page...");
            self.detailTextLabel.text = @"Go to page X of Y";
            [self.activityView stopAnimating];
            self.imageView.hidden = NO;
                //this animation caused a crash when case ...Loading: was after it
                //dont know wtf
                //[UIView animateWithDuration:.3
                 //                animations:^{
                 //                    self.imageView.transform = CGAffineTransformMakeRotation(M_PI);
                 //                }
                // ];            
			break;

            
        /*Customize for last page */    
        case AwfulPullForActionStateNormal + AwfulPullForActionOnLastPage:
            self.textLabel.text = @"End of the Thread";
            self.detailTextLabel.text = @"Pull up to refresh...";
            self.accessoryView.hidden = NO;
            [self.activityView stopAnimating];
            break;
            
        case AwfulPullForActionStateLoading + AwfulPullForActionOnLastPage:
            self.textLabel.text = @"Loading...";
            self.detailTextLabel.text = nil;
            self.accessoryView.hidden = YES;
            [self.activityView startAnimating];
            self.imageView.hidden = YES;
            break;
            
            
            
        case AwfulPullForActionStateRelease + AwfulPullForActionOnLastPage:
            self.textLabel.text = @"Release to refresh...";
            self.detailTextLabel.text = @"Pull down to cancel";
            self.accessoryView.hidden = YES;
            [self.activityView stopAnimating];
            self.imageView.hidden = NO;
            break;
            
            
        case AwfulPullForActionStatePulling + AwfulPullForActionOnLastPage:
            self.textLabel.text = @"Pull up to refresh";
            self.detailTextLabel.text = nil;
            self.accessoryView.hidden = NO;
            [self.activityView stopAnimating];
            self.imageView.hidden = NO;
            break;

	}
    [self setNeedsLayout];
}

@end
