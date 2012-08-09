//
//  AwfulYOSPOSRefreshControl.m
//  Awful
//
//  Created by me on 8/9/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulYOSPOSRefreshControl.h"
#import "AwfulCustomForumYOSPOS.h"
#import "AwfulYOSPOSFakeShell.h"

@implementation AwfulYOSPOSRefreshControl
@synthesize scrollView = _scrollView;
//fake wget refresh control

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.title.font = [UIFont fontWithName:@"Courier" size:10];
    self.title.numberOfLines = 0;
    self.title.lineBreakMode = UILineBreakModeCharacterWrap;
    self.title.clipsToBounds = NO;
    self.title.textColor = [UIColor YOSPOSGreenColor];
    self.title.backgroundColor = [UIColor blackColor];
    self.title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.title.tag = 0;
    
    [self.title addObserver:self
                 forKeyPath:@"text"
                    options:(NSKeyValueObservingOptionNew)
                    context:nil
     ];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:frame];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview:self.scrollView];
    
    [self.scrollView addSubview:self.title];
    
    self.subtitle.textColor = [UIColor blackColor];
    self.subtitle.font = [UIFont fontWithName:@"Courier" size:12];
    
    [[self.layer.sublayers objectAtIndex:0] removeFromSuperlayer];
    self.backgroundColor = [UIColor blackColor];
    self.imageView.image = nil;
    self.imageView2.image = nil;
    [self.imageView removeFromSuperview];
    [self.imageView2 removeFromSuperview];
    [self.innerCell removeFromSuperview];
    
    _shell = [[AwfulYOSPOSFakeShell alloc] initWithLabel:self.title];
    
    return self;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.scrollView.frame = self.frame;
    self.scrollView.foY = 0;
    self.scrollView.fsW = 320;
}

-(void) setState:(AwfulRefreshControlState)state {
    [super setState:state];
    self.title.text = nil;
    self.subtitle.text = nil;
    
    if (state == AwfulRefreshControlStateLoading) {
        [self.shell execute];
    }
}


-(void) didScrollInScrollView:(UIScrollView *)scrollView {
    [super didScrollInScrollView:scrollView];
    
    NSString *shellCommand = @"wget --progress=dot http://forums.somethingawful.com/forumdisplay.php?forumid=219 | mail -s \"forumdisplay.php?forumid=219\" \"user@forums.somethingawful.com\"";
    
    
    CGFloat scrollAmount = scrollView.contentOffset.y;
    if (scrollAmount > 0 && self.state == AwfulRefreshControlStateNormal) return;
    
    CGFloat threshhold = -2.25*self.fsH;
    CGFloat limit = -self.fsH;
    
    CGFloat scrollPct = (scrollAmount - limit)/(threshhold - limit);
    scrollPct = scrollPct < 0? 0 : scrollPct;
    scrollPct = scrollPct > 1? 1 : scrollPct;
    
    int length = shellCommand.length;
    int substringLength = length * scrollPct;
    
    self.shell.currentCommand = [shellCommand substringToIndex:substringLength];
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.title) {
        [self.title sizeToFit];
        self.title.fsW = 320;
        self.scrollView.contentSize = self.title.frame.size;
        self.scrollView.contentOffset = CGPointMake(0, self.title.fsH - self.scrollView.fsH);
    }
}

@end

