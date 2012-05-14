//
//  AwfulPullToNavigateView.m
//  Awful
//
//  Created by me on 5/10/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoadingFooterView.h"
#import "AwfulPage.h"

#define FLIP_ANIMATION_DURATION 0.18f

@implementation AwfulLoadingFooterView
@synthesize state = _state;
@synthesize onLastPage = _onLastPage;
@synthesize scrollView = _scrollView;
@synthesize autoF5 = _autoF5;

-(id) init {
    self = [super initWithFrame:CGRectMake(0, 0, 200, 65)];
    self.autoF5 = [[UISwitch alloc] initWithFrame:CGRectMake(self.fsW - 100,0 , 0, 0)];
    self.autoF5.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|
                                    UIViewAutoresizingFlexibleTopMargin|
                                    UIViewAutoresizingFlexibleBottomMargin;
    //[self addSubview:self.autoF5];
    
    self.onLastPage = YES;
    return self;
}

-(void) setOnLastPage:(BOOL)onLastPage {
    _onLastPage = onLastPage;
    
    if (onLastPage) {
        self.autoF5.hidden = NO;
        self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 65.0f, 0);
        self.scrollView.delegate = self;
    }
    
    else {
        self.autoF5.hidden = YES;
        self.scrollView.contentInset = UIEdgeInsetsZero;
        self.scrollView.delegate = nil;
        
    }
    
    
}


#pragma mark ScrollView Methods

-(void) setScrollView:(UIScrollView *)scrollView {
    _scrollView = scrollView;
    self.backgroundColor = [UIColor lightGrayColor];
    [self removeFromSuperview];
    [scrollView addSubview:self];
    
    scrollView.delegate = self.onLastPage? nil : self; 
    
    self.frame = CGRectMake(0, scrollView.contentSize.height, scrollView.contentSize.width, 65.0f);
    [self egoRefreshScrollViewDataSourceDidFinishedLoading:scrollView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (self.foY != scrollView.contentSize.height) {
        //quick position check and reset, it got positioned wrong a few times in testing
        self.foY = scrollView.contentSize.height;
    }
    
    if (self.onLastPage) return;
    
    
    CGFloat scrollAmount = scrollView.contentOffset.y + scrollView.frame.size.height;
    CGFloat threshhold = scrollView.contentSize.height + 65.0f;
    
	NSLog(@"Scrollview offset:%f vs contentsize:%f", scrollAmount, threshhold);
    
	if (self.state == EGOOPullRefreshLoading) {
		//fixme
		scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 65.0f, 0.0f);
		
	} else if (scrollView.isDragging) {
		
		BOOL _loading = NO;
		if ([self.delegate respondsToSelector:@selector(egoRefreshTableHeaderDataSourceIsLoading:)]) {
			_loading = [self.delegate egoRefreshTableHeaderDataSourceIsLoading:self];
		}
		
		if (self.state == EGOOPullRefreshPulling && scrollAmount < threshhold && scrollAmount > scrollView.contentSize.height && !_loading) {
			[self setState:EGOOPullRefreshNormal];
		} else if (self.state == EGOOPullRefreshNormal && scrollAmount > threshhold && !_loading) {
			[self setState:EGOOPullRefreshPulling];
		}
		
		if (scrollView.contentInset.bottom != 0) {
			scrollView.contentInset = self.onLastPage? UIEdgeInsetsMake(0, 0, 65, 0) : UIEdgeInsetsZero;
		}
		
	}

}

-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate 
{
	
    if (self.onLastPage) return;
	BOOL _loading = NO;
	if ([self.delegate respondsToSelector:@selector(egoRefreshTableHeaderDataSourceIsLoading:)]) {
		_loading = [self.delegate egoRefreshTableHeaderDataSourceIsLoading:self];
	}
	
	if (scrollView.contentOffset.y + scrollView.frame.size.height >= scrollView.contentSize.height + 65.0f && !_loading) {
		
		if ([self.delegate respondsToSelector:@selector(awfulFooterDidTriggerLoad:)]) {
			[(AwfulPage*)self.delegate awfulFooterDidTriggerLoad:self];
		}
		
		[self setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 60.0f, 0.0f);
		[UIView commitAnimations];
		
	}
	
}

- (void)egoRefreshScrollViewDataSourceDidFinishedLoading:(UIScrollView *)scrollView 
{		
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[scrollView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[self setState:EGOOPullRefreshNormal];
}

- (void)setState:(EGOPullRefreshState)aState
{
	_state = aState;
	switch (aState) {
		case EGOOPullRefreshPulling:
			
			self.statusLabel.text = @"Release for next page...";
			[CATransaction begin];
			[CATransaction setAnimationDuration:FLIP_ANIMATION_DURATION];
			self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 180.0f, 0.0f, 0.0f, 1.0f);
			[CATransaction commit];
			
			break;
		case EGOOPullRefreshNormal:
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
		case EGOOPullRefreshLoading:
			
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
