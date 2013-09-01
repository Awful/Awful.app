//  AwfulScreenCoverView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScreenCoverView.h"

@interface AwfulScreenCoverView ()

@property (weak, nonatomic) id target;
@property (nonatomic) SEL action;

@end


@implementation AwfulScreenCoverView

- (id)initWithWindow:(UIWindow *)window
{
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"Dismiss";
    self.accessibilityHint = @"Double-tap to dismiss actions window";
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [window addSubview:self];
    return self;
}

- (void)setTarget:(id)target action:(SEL)action
{
    self.target = target;
    self.action = action;
}

#pragma mark - UIView

- (void)dealloc
{
    [self stopObservingInterfaceOrientationChanges];
}

- (void)didMoveToWindow
{
    if (self.window) {
        [self rotateAndReposition];
        [self observeInterfaceOrientationChanges];
    } else {
        [self stopObservingInterfaceOrientationChanges];
    }
}

- (void)rotateAndReposition
{
    UIScreen *screen = self.window.screen;
    CGRect frame = screen.bounds;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        CGFloat swap = CGRectGetWidth(frame);
        frame.size.width = CGRectGetHeight(frame);
        frame.size.height = swap;
    }
    CGFloat angle;
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft: angle = -M_PI / 2; break;
        case UIInterfaceOrientationLandscapeRight: angle = M_PI / 2; break;
        case UIInterfaceOrientationPortraitUpsideDown: angle = M_PI; break;
        case UIInterfaceOrientationPortrait: angle = 0; break;
    }
    self.transform = CGAffineTransformMakeRotation(angle);
    self.frame = frame;
}

- (void)observeInterfaceOrientationChanges
{
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(statusBarOrientationDidChange:)
                       name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)statusBarOrientationDidChange:(NSNotification *)note
{
    [self rotateAndReposition];
}

- (void)stopObservingInterfaceOrientationChanges
{
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification
                        object:nil];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    // Only allow touches to our passthrough views; swallow the rest.
    return [self shouldInterceptTouchesAtPoint:point];
}

- (BOOL)shouldInterceptTouchesAtPoint:(CGPoint)point
{
    for (UIView *view in self.passthroughViews) {
        if (![view.window isEqual:self.window]) continue;
        
        // Doc for -[UIView hitTest:withEvent:] outlines this criteria for ignoring a view.
        if (view.hidden || !view.userInteractionEnabled || view.alpha < 0.01) {
            continue;
        }
        
        CGPoint localPassthroughPoint = [view convertPoint:point fromView:self];
        if ([view pointInside:localPassthroughPoint withEvent:nil]) return NO;
    }
    return YES;

}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // noop
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    // noop
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    // noop
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    // "Touch up outside all passthrough views".
    CGPoint point = [[touches anyObject] locationInView:self];
    if ([self shouldInterceptTouchesAtPoint:point]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        [self.target performSelector:self.action];
        
        #pragma clang diagnostic pop
    }
}

@end
