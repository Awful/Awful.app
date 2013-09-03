//  AwfulNavigationBar.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNavigationBar.h"

@implementation AwfulNavigationBar

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.tintColor = [UIColor whiteColor];
    self.barTintColor = [UIColor colorWithRed:0.078 green:0.514 blue:0.694 alpha:1];
    self.translucent = NO;
    self.titleTextAttributes = @{ NSForegroundColorAttributeName: [UIColor whiteColor] };
    
    UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
    [longPress addTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPress];
    return self;
}

- (void)longPress:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    if (!self.backItem) return;
    UINavigationController *nav = self.delegate;
    if (![nav isKindOfClass:[UINavigationController class]]) return;
    UIView *leftmost;
    for (UIView *subview in self.subviews) {
        if (leftmost && CGRectGetMinX(leftmost.frame) < CGRectGetMinX(subview.frame)) continue;
        if (CGRectGetWidth(subview.frame) > CGRectGetWidth(self.frame) / 2) continue;
        leftmost = subview;
    }
    CGRect backFrame = leftmost ? leftmost.frame : CGRectMake(5, 0, 100, 40);
    if (CGRectContainsPoint(backFrame, [recognizer locationInView:self])) {
        [nav popToRootViewControllerAnimated:YES];
    }
}

@end
