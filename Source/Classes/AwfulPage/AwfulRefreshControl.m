//
//  AwfulRefreshControl.m
//  Awful
//
//  Created by me on 6/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulRefreshControl.h"
#import <QuartzCore/QuartzCore.h>

@interface AwfulRefreshControl ()
@property (nonatomic) AwfulRefreshControlState state;
@end

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
        _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [self addSubview:self.activityView];
        
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

-(void) layoutSubviews {
    [super layoutSubviews];
    self.activityView.frame = self.imageView.frame;
}

-(void) didScrollInScrollView:(UIScrollView *)scrollView {
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
        return;
    }
}


-(void) setState:(AwfulRefreshControlState)state {
    if (self.state == state && 
        state != AwfulRefreshControlStateLoading &&
        [[NSDate date] timeIntervalSinceDate:self.loadedDate] < 60)
        return;
    
    _state = state;
    
    switch (state) {
        case AwfulRefreshControlStateLoading:
            self.title.text = @"Refreshing...";
            self.subtitle.text = @"Swipe left to cancel";
            self.imageView.hidden = YES;
            [self.activityView startAnimating];
            break;
            
        case AwfulRefreshControlStatePulling:
            self.title.text = @"Keep pulling to refresh";
            self.subtitle.text = self.stringTimeIntervalSinceLoad;
            self.imageView.hidden = NO;
            [self.activityView stopAnimating];
            break;
            
        case AwfulRefreshControlStateNormal:
            self.title.text = @"Pull to refresh...";
            self.subtitle.text = self.stringTimeIntervalSinceLoad;
            self.imageView.hidden = NO;
            [self.activityView stopAnimating];
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

@end
