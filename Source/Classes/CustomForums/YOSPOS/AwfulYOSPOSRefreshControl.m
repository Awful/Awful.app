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
@synthesize tty = _tty;
//fake wget refresh control

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    
    [self.tty addObserver:self
               forKeyPath:@"text"
                  options:(NSKeyValueObservingOptionNew)
                  context:nil
     ];
    
    
    [[self.layer.sublayers objectAtIndex:0] removeFromSuperlayer];
    self.backgroundColor = [UIColor blackColor];
    self.imageView.image = nil;
    self.imageView2.image = nil;
    [self.imageView removeFromSuperview];
    [self.imageView2 removeFromSuperview];
    [self.innerCell removeFromSuperview];
    
    _shell = [[AwfulYOSPOSFakeShell alloc] initWithTextView:self.tty];
    
    return self;
}

-(UITextView*) tty {
    if (!_tty) {
        _tty = [UITextView new];
        _tty.font = [UIFont fontWithName:@"Courier" size:10];
        _tty.textColor = [UIColor YOSPOSGreenColor];
        _tty.backgroundColor = [UIColor blackColor];
        _tty.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_tty];
    }
    return _tty;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.tty.frame = self.frame;
    self.tty.foY = 0;
    self.tty.fsW = 320;
}

-(void) setState:(AwfulRefreshControlState)state {
    if (state == AwfulRefreshControlStateLoading) {
        [self.shell execute];
    }
    
    [super setState:state];
    self.title.text = nil;
    self.subtitle.text = nil;
    
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
    if (object == self.tty) {
        self.tty.fsW = 320;
        self.tty.contentOffset = CGPointMake(0, self.tty.contentSize.height - self.tty.fsH);
        //[self.tty scrollRangeToVisible:NSMakeRange(self.tty.text.length, 0)];
    }
}

@end

