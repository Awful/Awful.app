//
//  AwfulLastPageControl.m
//  Awful
//
//  Created by me on 7/19/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLastPageControl.h"
#import "AwfulAnimatedGifActivityIndicatorView.h"

@implementation AwfulLastPageControl
@synthesize state = _state;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.imageView.image = [UIImage imageNamed:@"emot-smith.gif"];
        self.innerCell.accessoryView = [UISwitch new];
        self.imageView2.hidden = YES;
    }
    return self;
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
            self.changeInsetToShow = YES;
            break;
            
        case AwfulRefreshControlStatePulling:
            self.title.text = @"Keep pulling to refresh";
            self.subtitle.text = nil;
            self.imageView.image = [UIImage imageNamed:@"emot-unsmith.gif"];
            self.imageView.hidden = NO;
            [self.activityView stopAnimating];
            break;
            
        case AwfulRefreshControlStateNormal:
            self.title.text = @"End of the thread...";
            self.subtitle.text = @"Pull to refresh...";
            self.imageView.image = [UIImage imageNamed:@"emot-smith.gif"];
            self.imageView.hidden = NO;
            self.changeInsetToShow = YES;
            [self.activityView stopAnimating];
            break;
    }
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    
}

-(UIActivityIndicatorView*) activityView {
    if (!_activityView) {
        _activityView = [[AwfulAnimatedGifActivityIndicatorView alloc] initWithImagePath:
                         [[NSBundle mainBundle] pathForResource:@"emot-f5" ofType:@"gif"]];
        [self addSubview:self.activityView];
    }
    return _activityView;
}

@end
