//
//  AwfulLastPageControl.m
//  Awful
//
//  Created by me on 7/19/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLastPageControl.h"
#import "AwfulAnimatedGifActivityIndicatorView.h"

static int const AwfulRefreshControlStateAutoRefresh = 16;

@implementation AwfulLastPageControl
@synthesize autoRefreshView = _autoRefreshView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.imageView.image = [UIImage imageNamed:@"emot-f5.gif"];
        self.imageView2.hidden = YES;
        self.innerCell.accessoryView = self.autoRefreshView;
        _autoRefreshEnabled = NO;
    }
    return self;
}

-(void) setState:(AwfulRefreshControlState)state {
    [super setState:state];
    self.changeInsetToShow = YES;
    self.imageView2.hidden = YES;
}

-(void) changeLabelTextForCurrentState {
    int state = self.state | (self.autoRefreshEnabled * AwfulRefreshControlStateAutoRefresh);
    
    int seconds = round([self.refreshTimer.fireDate timeIntervalSinceNow]);
    
    switch (state) {
        case AwfulRefreshControlStateLoading:
        case AwfulRefreshControlStateLoading|AwfulRefreshControlStateAutoRefresh:
            self.title.text = @"Refreshing...";
            self.subtitle.text = @"Swipe left to cancel";
            break;
            
        case AwfulRefreshControlStatePulling:
            self.title.text = @"Keep pulling to refresh";
            self.imageView.image = [UIImage imageNamed:@"emot-unsmith.gif"];
            self.subtitle.text = @"";
            break;
            
        case AwfulRefreshControlStateNormal:
            self.title.text = @"End of the thread...";
            self.subtitle.text = @"Pull to refresh...";
            self.imageView.image = [UIImage imageNamed:@"emot-smith.gif"];
            break;
            
        case AwfulRefreshControlStateAutoRefresh|AwfulRefreshControlStateNormal:
            self.title.text = [@"Auto-refreshing in " stringByAppendingFormat:@"%i second%@",seconds, (seconds==1)? @"" : @"s"];
            self.subtitle.text = @"Pull to force refresh...";
            self.imageView.image = [UIImage imageNamed:@"emot-f5.gif"];
            break;
            
            
        case AwfulRefreshControlStateAutoRefresh|AwfulRefreshControlStatePulling:
            self.title.text = @"Auto-refresh enabled";
            self.subtitle.text = @"Keep pulling to force refresh...";
            self.imageView.image = [UIImage imageNamed:@"emot-f5.gif"];
            break;
            
    }
}

-(UIActivityIndicatorView*) activityView {
    if (!_activityView) {
        _activityView = [[AwfulAnimatedGifActivityIndicatorView alloc] initWithImagePath:
                         [[NSBundle mainBundle] pathForResource:@"emot-f5" ofType:@"gif"]];
        [self addSubview:self.activityView];
    }
    return _activityView;
}

-(UIView*) autoRefreshView {
    if (!_autoRefreshView) {
        UISwitch* autoF5 = [[UISwitch alloc] initWithFrame:CGRectMake(10, 9, 50, 20)];
        autoF5.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
        [autoF5 addTarget:self action:@selector(didChangeAutoRefreshSwitch:) forControlEvents:(UIControlEventValueChanged)];
        
        UILabel* lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 35, 100, 15)];
        lbl.text = @"Auto-refresh";
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:11];
        lbl.textAlignment = UITextAlignmentCenter;
        lbl.backgroundColor = [UIColor clearColor];
        
        _autoRefreshView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, self.fsH)];
        _autoRefreshView.backgroundColor = [UIColor clearColor];
        
        [_autoRefreshView addSubview:autoF5];
        [_autoRefreshView addSubview:lbl];
    }
    return _autoRefreshView;
}

-(void) didChangeAutoRefreshSwitch:(UISwitch*)s {
    _autoRefreshEnabled = s.enabled;
    
    if (s.enabled) {
        self.updateUITimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                              target:self
                                                            selector:@selector(changeLabelTextForCurrentState)
                                                            userInfo:nil
                                                             repeats:YES];
        
        
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                                             target:self
                                                           selector:@selector(doAutoRefresh)
                                                           userInfo:nil
                                                            repeats:YES];
    }
    else {
        self.updateUITimer = nil;
        self.refreshTimer = nil;
        [self changeLabelTextForCurrentState];
        
    }
}

-(void) doAutoRefresh {
    self.state = AwfulRefreshControlStateLoading;
}

@end
