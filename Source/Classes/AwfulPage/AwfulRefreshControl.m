//
//  AwfulRefreshControl.m
//  Awful
//
//  Created by me on 6/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulRefreshControl.h"
#import <QuartzCore/QuartzCore.h>

@implementation AwfulRefreshControl
@synthesize refreshing = _refreshing;
@synthesize scrollAmount = _scrollAmount;
@synthesize scrollView = _scrollView;
@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize imageView = _imageView;
@synthesize activityView = _activityView;
@synthesize state = _state;
@synthesize loadedDate = _loadedDate;
@synthesize userScrolling = _userScrolling;
@synthesize canSwipeToCancel = _canSwipeToCancel;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:(UITableViewCellStyleSubtitle) reuseIdentifier:@"pullToRefresh"];
        cell.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _title = cell.textLabel;
        _subtitle = cell.detailTextLabel;
        _imageView = cell.imageView;
        
        self.imageView.image = [UIImage imageNamed:@"smile.gif"];
        
        self.canSwipeToCancel = YES;
        self.state = AwfulRefreshControlStateNormal;
        
        cell.frame = CGRectMake(0, 0, self.fsW, self.fsH);
        [self addSubview:cell];
        
        self.backgroundColor = [UIColor magentaColor];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor whiteColor];
        
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = self.bounds;
        gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor blackColor] CGColor], 
                           (id)[[UIColor colorWithRed:.09 green:.24 blue:.40 alpha:1] CGColor], 
                           nil];
        [self.layer insertSublayer:gradient atIndex:0];
    }
    return self;
}

-(UIActivityIndicatorView*) activityView {
    if (!_activityView) {
        _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [self addSubview:self.activityView];
    }
    return _activityView;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.activityView.frame = self.imageView.frame;
}

-(void) didScrollInScrollView:(UIScrollView *)scrollView {
    if (!self.userScrolling) return;
    
    CGFloat scrollAmount = scrollView.contentOffset.y;
    if (scrollAmount > 0 && self.state == AwfulRefreshControlStateNormal) return;
    
    CGFloat threshhold = -2.25*self.fsH;
    CGFloat limit = -self.fsH;
    
    //normal
    if (scrollAmount >= limit) {
        self.state = AwfulRefreshControlStateNormal;
        return;
    }
    
    //Header Pulling
    if (scrollAmount < limit && scrollAmount >= threshhold) {
        self.state = AwfulRefreshControlStatePulling;
        return;
    }    
    
    //Header Loading
    if (scrollAmount < threshhold) {
        self.state = AwfulRefreshControlStateLoading;
        self.userScrolling = NO;
        //[scrollView setContentOffset:CGPointMake(0, -self.fsH) animated:YES];
        return;
    }
}


-(void) setState:(AwfulRefreshControlState)state {
    if (self.state == state) //&&
        //state != AwfulRefreshControlStateLoading &&
        //[[NSDate date] timeIntervalSinceDate:self.loadedDate] < 60)
        return;
    
    _state = state;
    
    switch (state) {
        case AwfulRefreshControlStateLoading:
            self.title.text = @"Refreshing...";
            self.subtitle.text = @"Swipe left to cancel";
            self.imageView.hidden = YES;
            [self.activityView startAnimating];
            self.userScrolling = NO;
            self.changeInsetToShow = YES;
            break;
            
        case AwfulRefreshControlStatePulling:
            self.title.text = @"Keep pulling to refresh";
            self.subtitle.text = self.stringTimeIntervalSinceLoad;
            self.imageView.hidden = NO;
            [self.activityView stopAnimating];
            //self.changeInsetToShow = NO;
            break;
            
        case AwfulRefreshControlStateNormal:
            self.title.text = @"Pull to refresh...";
            self.subtitle.text = self.stringTimeIntervalSinceLoad;
            self.imageView.hidden = NO;
            [self.activityView stopAnimating];
            self.changeInsetToShow = NO;
            break;
    }
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
                                       
}

-(NSString*) stringTimeIntervalSinceLoad {
    NSTimeInterval s = [[NSDate date] timeIntervalSinceDate:self.loadedDate];
    int m = (int)s/60;
    if (m <= 0)
        return @"Updated less than a minute ago";
    else if (m < 50)
        return [NSString stringWithFormat:@"Updated %i minute%@ ago", m, (m==1)? @"" : @"s"];
    else if (m >= 50 && m <= 70)
        return @"Updated about an hour ago";
    else
        return @"Updated over an hour ago";
    
    return @"???";
}

-(void) setChangeInsetToShow:(BOOL)show {
    CGFloat inset = show? self.fsH : 0;
    
    UIScrollView* scrollView = (UIScrollView*)self.superview;
    UIEdgeInsets insets = scrollView.contentInset;
    if (inset == insets.top) return;
    insets.top = inset;
    
    //if (show) {
        scrollView.userInteractionEnabled = NO;
        [UIView animateWithDuration:.3
                         animations:^{
                             
                             scrollView.contentInset = insets;
                         }
                         completion:^(BOOL finished) {
                             scrollView.userInteractionEnabled = YES;
                         }
         ];
    //}
}

-(void) setCanSwipeToCancel:(BOOL)canSwipeToCancel {
    _canSwipeToCancel = canSwipeToCancel;
    if (canSwipeToCancel) {
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self 
                                                                                    action:@selector(didSwipeToCancel:)
                                           ];
        
        swipe.numberOfTouchesRequired = 1;
        swipe.direction = (UISwipeGestureRecognizerDirectionLeft);
        [self addGestureRecognizer:swipe];
    }
    else {
        if (self.gestureRecognizers.count > 0) 
            [self removeGestureRecognizer:[self.gestureRecognizers objectAtIndex:0]];
    }
}

-(void) didSwipeToCancel:(UISwipeGestureRecognizer*)swipe {
    [self sendActionsForControlEvents:UIControlEventTouchCancel];
    [UIView animateWithDuration:.3 
                     animations:^{
                         self.foX = -self.fsW;
                         self.changeInsetToShow = NO;
                     }
                     completion:^(BOOL finished) {
                         self.state = AwfulRefreshControlStateNormal;
                         self.foX = 0;
                     }
    ];
}



@end
