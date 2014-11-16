//  AwfulNavigationBar.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNavigationBar.h"

@implementation AwfulNavigationBar

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        
        // For whatever reason, translucent navbars with a barTintColor do not necessarily blur their backgrounds. An iPad 3, for example, blurs a bar without a barTintColor but is simply semitransparent with a barTintColor. The semitransparent, non-blur effect looks awful, so just turn it off.
        self.translucent = NO;
        
        // Setting the barStyle to UIBarStyleBlack results in an appropriate status bar style.
        self.barStyle = UIBarStyleBlack;
        
        UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
        [longPress addTarget:self action:@selector(longPress:)];
        [self addGestureRecognizer:longPress];
    }
    return self;
}

- (void)longPress:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    if (!self.backItem) return;
    UINavigationController *nav = (UINavigationController*)self.delegate;
    if (![nav isKindOfClass:[UINavigationController class]]) return;
    
    // Find the leftmost, widest subview whose width is less than half of the navbar's.
    NSMutableArray *subviews = [self.subviews mutableCopy];
    [subviews filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *view, NSDictionary *bindings) {
        return CGRectGetWidth(view.frame) < CGRectGetWidth(self.frame) / 2;
    }]];
    [subviews sortUsingComparator:^(UIView *a, UIView *b) {
        if (CGRectGetMinX(a.frame) < CGRectGetMinX(b.frame)) {
            return NSOrderedAscending;
        } else if (CGRectGetMinX(a.frame) > CGRectGetMinX(b.frame)) {
            return NSOrderedDescending;
        }
        if (CGRectGetWidth(a.frame) > CGRectGetWidth(b.frame)) {
            return NSOrderedAscending;
        } else if (CGRectGetWidth(a.frame) < CGRectGetWidth(b.frame)) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    UIView *leftmost = subviews[0];
    
    if (CGRectContainsPoint(leftmost.frame, [recognizer locationInView:self])) {
        [nav popToRootViewControllerAnimated:YES];
    }
}

@end
