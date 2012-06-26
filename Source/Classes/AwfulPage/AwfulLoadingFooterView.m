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
//@synthesize scrollView = _scrollView;
@synthesize autoF5 = _autoF5;
@synthesize activityView = _activityView;
@synthesize loadedDate = _loadedDate;

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
    autoF5Label.frame = CGRectMake(0, 45, self.autoF5.fsW, 15);
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
    /*
    [self.autoF5 addTarget:self 
                          action:@selector(didSwitchAutoF5:) 
                forControlEvents:UIControlEventValueChanged];
    */
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
    if (_state == aState) return;
    
	_state = aState;
    int onLastPage = self.onLastPage? AwfulPullForActionOnLastPage : 0;
    int autoF5enabled = self.autoF5.on? AwfulPullForActionAutoF5 : 0;
    
    if (self.gestureRecognizers.count > 0 && aState != AwfulPullForActionStateLoading)
        [self removeGestureRecognizer:[self.gestureRecognizers objectAtIndex:0]];
    
	switch (aState + onLastPage + autoF5enabled) {
		case AwfulPullForActionStateNormal:
        case AwfulPullForActionStatePulling:
            self.textLabel.text = (@"Pull up for next page...");
            //self.detailTextLabel.text = [NSString stringWithFormat:@"Go to page X of Y", ;
            [self.activityView stopAnimating];
            self.imageView.hidden = NO;          
			break;
            
		case AwfulPullForActionStateLoading:
			self.textLabel.text = @"Loading...";
            self.detailTextLabel.text = @"Swipe left to cancel";
            self.imageView.hidden = YES;
			[self.activityView startAnimating];
			return;
			break;

            
        /*Customize for last page */    
        case AwfulPullForActionStateNormal + AwfulPullForActionOnLastPage:
            self.textLabel.text = @"End of the Thread";
            self.detailTextLabel.text = @"Pull up to refresh...";
            NSLog(@"%@",self.accessoryView);
            self.accessoryView.hidden = NO;
            [self.activityView stopAnimating];
            self.imageView.image = [UIImage imageNamed:@"frown.gif"];
            self.imageView.hidden = NO;
            break;
            
        case AwfulPullForActionStateLoading + AwfulPullForActionOnLastPage:
            self.textLabel.text = @"Loading...";
            self.detailTextLabel.text = @"Swipe left to cancel";
            self.accessoryView.hidden = NO;
            [self.activityView startAnimating];
            self.imageView.hidden = YES;
            break;
            
        case AwfulPullForActionStatePulling + AwfulPullForActionOnLastPage:
            self.textLabel.text = @"Pull up to refresh";
            self.detailTextLabel.text = nil;
            self.accessoryView.hidden = NO;
            [self.activityView stopAnimating];
            self.imageView.hidden = NO;
            break;
            
            /*Customize for last page and autorefreshing */    
        case AwfulPullForActionStateNormal + AwfulPullForActionOnLastPage + AwfulPullForActionAutoF5:
        case AwfulPullForActionStatePulling + AwfulPullForActionOnLastPage + AwfulPullForActionAutoF5:
            self.textLabel.text = @"Auto-refreshing every minute";
            self.detailTextLabel.text = @"Pull up to force refresh...";
            self.accessoryView.hidden = NO;
            [self.activityView stopAnimating];
            self.imageView.hidden = NO;
            self.imageView.image = [UIImage imageNamed:@"emot-f5.gif"];
            break;
            
        case AwfulPullForActionStateLoading + AwfulPullForActionOnLastPage + AwfulPullForActionAutoF5:
            self.textLabel.text = @"Loading...";
            self.detailTextLabel.text = @"Swipe left to cancel";
            self.accessoryView.hidden = NO;
            [self.activityView startAnimating];
            self.imageView.hidden = YES;
            break;
	}
    [self setNeedsLayout];
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

-(void) didSwitchAutoF5:(UISwitch *)switchObj {

}

/*
-(void) scrollViewDidScroll:(UIScrollView*)scrollView {
    //UIScrollView *scrollView = ((AwfulPullForActionController*)msg.object).scrollView;
    
    
}

-(void) scrollViewDidEndDragging:(UIScrollView*)scrollView {
    
}
*/
@end
