//
//  AwfulPullToRefreshControl.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "AwfulPullToRefreshControl.h"
#import <QuartzCore/QuartzCore.h>

// If we set rotation to exactly M_PI, Core Animation decides which direction to rotate (i.e. it
// doesn't matter if we say positive or negative M_PI).
#define M_ALMOST_PI (M_PI - 0.00001)


@interface ArrowView : UIView

@property (nonatomic) UIColor *color;

- (void)setRotation:(CGFloat)radians animated:(BOOL)animated;

@end


@interface AwfulPullToRefreshControl ()

@property (readonly, nonatomic) UIScrollView *scrollView;

@property (nonatomic) UIControlState customState;

@property (nonatomic) AwfulScrollViewPullObserver *observer;

@property (weak, nonatomic) ArrowView *arrow;

@property (weak, nonatomic) UIActivityIndicatorView *spinner;

@property (weak, nonatomic) UILabel *titleLabel;

@property (readonly, nonatomic) NSMutableDictionary *titles;

@end


@implementation AwfulPullToRefreshControl

- (id)initWithDirection:(AwfulScrollViewPullDirection)direction
{
    if (!(self = [super initWithFrame:CGRectMake(0, 0, 320, 55)])) return nil;
    _direction = direction;
    _titles = [@{
        @(UIControlStateNormal): @"Pull to refresh…",
        @(UIControlStateSelected): @"Release to refresh…",
        @(AwfulControlStateRefreshing): @"Refreshing…"
    } mutableCopy];
    
    ArrowView *arrow = [[ArrowView alloc] initWithFrame:CGRectMake(0, 0, 22, 48)];
    arrow.backgroundColor = [UIColor clearColor];
    [self addSubview:arrow];
    _arrow = arrow;
    [self resetArrow];
    
    UIActivityIndicatorView *spinner = [UIActivityIndicatorView new];
    spinner.alpha = 0;
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    [self addSubview:spinner];
    _spinner = spinner;
    
    UILabel *titleLabel = [UILabel new];
    titleLabel.text = _titles[@(UIControlStateNormal)];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textColor = [UIColor lightGrayColor];
    titleLabel.backgroundColor = [UIColor clearColor];
    [titleLabel sizeToFit];
    [self addSubview:titleLabel];
    _titleLabel = titleLabel;
    return self;
}

- (void)setTriggerOffset:(CGFloat)triggerOffset
{
    if (_triggerOffset == triggerOffset) return;
    _triggerOffset = triggerOffset;
    self.observer.triggerOffset = triggerOffset + self.bounds.size.height;
    
}

- (UIScrollView *)scrollView
{
    return (UIScrollView *)[self superview];
}

- (BOOL)isRefreshing
{
    return !!(self.state & AwfulControlStateRefreshing);
}

- (void)setRefreshing:(BOOL)refreshing
{
    [self setRefreshing:refreshing animated:NO];
}

- (void)setRefreshing:(BOOL)refreshing animated:(BOOL)animated
{
    if (self.refreshing == refreshing) return;
    [self willChangeValueForKey:@"refreshing"];
    if (refreshing) {
        self.customState |= AwfulControlStateRefreshing;
    } else {
        self.customState &= ~AwfulControlStateRefreshing;
    }
    [self didChangeValueForKey:@"refreshing"];
    
    // Change title immediately if we're refreshing. Otherwise change it after animations.
    if (refreshing) {
        [self updateTitleLabel];
    }
    UIEdgeInsets contentInset = self.scrollView.contentInset;
    CGFloat insetChange = self.frame.size.height * (refreshing ? 1 : -1);
    if (self.direction == AwfulScrollViewPullDown) {
        contentInset.top += insetChange;
    } else if (self.direction == AwfulScrollViewPullUp) {
        contentInset.bottom += insetChange;
    }
    if (refreshing) {
        [self.spinner startAnimating];
    }
    [UIView animateWithDuration:animated ? 0.3 : 0
                          delay:0
                        options:(UIViewAnimationOptionAllowUserInteraction |
                                 UIViewAnimationOptionBeginFromCurrentState)
                     animations:^
    {
        self.scrollView.contentInset = contentInset;
        if (refreshing) {
            self.arrow.alpha = 0;
            self.spinner.alpha = 1;
        }
    } completion:^(BOOL _)
    {
        if (!refreshing) {
            [self.observer reset];
            self.selected = NO;
            self.arrow.alpha = 1;
            self.spinner.alpha = 0;
            [self.spinner stopAnimating];
            [self updateTitleLabel];
        }
    }];
}

- (void)resetArrow
{
    [self.arrow setRotation:self.direction == AwfulScrollViewPullDown ? 0 : M_ALMOST_PI
                   animated:NO];
}

- (NSString *)titleForState:(UIControlState)state
{
    NSString *title = self.titles[@(state)];
    if (title) return title;
    return self.titles[@(UIControlStateNormal)];
}

- (void)setTitle:(NSString *)title forState:(UIControlState)state
{
    self.titles[@(state)] = title;
    [self updateTitleLabel];
}

- (void)updateTitleLabel
{
    if (self.state & AwfulControlStateRefreshing) {
        self.titleLabel.text = [self titleForState:AwfulControlStateRefreshing];
    } else if (self.state & UIControlStateSelected) {
        self.titleLabel.text = [self titleForState:UIControlStateSelected];
    } else {
        self.titleLabel.text = [self titleForState:UIControlStateNormal];
    }
}

- (void)repositionWithinScrollView
{
    if (self.direction == AwfulScrollViewPullDown) {
        CGRect frame = self.frame;
        frame.origin.y = -frame.size.height;
        frame.size.width = self.superview.bounds.size.width;
        self.frame = frame;
    } else if (self.direction == AwfulScrollViewPullUp) {
        CGRect frame = self.frame;
        frame.origin.y = self.scrollView.contentSize.height;
        frame.size.width = self.scrollView.bounds.size.width;
        self.frame = frame;
    }
}

- (UIColor *)textColor
{
    return self.titleLabel.textColor;
}

- (void)setTextColor:(UIColor *)textColor
{
    self.titleLabel.textColor = textColor;
}

- (UIActivityIndicatorViewStyle)spinnerStyle
{
    return self.spinner.activityIndicatorViewStyle;
}

- (void)setSpinnerStyle:(UIActivityIndicatorViewStyle)spinnerStyle
{
    self.spinner.activityIndicatorViewStyle = spinnerStyle;
}

- (UIColor *)arrowColor
{
    return self.arrow.color;
}

- (void)setArrowColor:(UIColor *)arrowColor
{
    self.arrow.color = arrowColor;
}

#pragma mark - UIControl

- (UIControlState)state
{
    return [super state] | self.customState;
}

+ (NSSet *)keyPathsForValuesAffectingState
{
    return [[super keyPathsForValuesAffectingValueForKey:@"state"]
            setByAddingObject:@"customState" ];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    if (self.direction == AwfulScrollViewPullDown) {
        [self.arrow setRotation:(selected ? M_ALMOST_PI : 0) animated:YES];
    } else if (self.direction == AwfulScrollViewPullUp) {
        [self.arrow setRotation:(selected ? 0 : M_ALMOST_PI) animated:YES];
    }
    [self updateTitleLabel];
}

#pragma mark - UIView

- (void)layoutSubviews
{
    CGFloat leftOffset = CGRectGetMidX(self.bounds) - 98;
    CGRect arrowFrame = self.arrow.frame;
    arrowFrame.origin.x = leftOffset;
    arrowFrame.origin.y = floor((self.bounds.size.height - arrowFrame.size.height) / 2);
    self.arrow.frame = arrowFrame;
    self.spinner.center = self.arrow.center;
    
    CGRect titleFrame = self.titleLabel.frame;
    titleFrame.origin.x = leftOffset + 44;
    titleFrame.origin.y = floor((self.bounds.size.height - titleFrame.size.height) / 2);
    titleFrame.size.width = self.bounds.size.width - titleFrame.origin.x;
    self.titleLabel.frame = titleFrame;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if ([newSuperview isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)newSuperview;
        [self repositionWithinScrollView];
        if (self.direction == AwfulScrollViewPullUp) {
            [scrollView addObserver:self
                         forKeyPath:@"contentSize"
                            options:0
                            context:&KVOContext];
        }
        CGFloat triggerOffset = self.bounds.size.height + self.triggerOffset;
        self.observer = [[AwfulScrollViewPullObserver alloc] initWithScrollView:scrollView
                                                                      direction:self.direction
                                                                  triggerOffset:triggerOffset];
        __weak AwfulPullToRefreshControl *weakSelf = self;
        self.observer.willTrigger = ^{ weakSelf.selected = YES; };
        self.observer.willNotTrigger = ^{ weakSelf.selected = NO; };
        self.observer.didTrigger = ^
        {
            [weakSelf setRefreshing:YES animated:YES];
            [weakSelf sendActionsForControlEvents:UIControlEventValueChanged];
        };
    } else {
        if (self.direction == AwfulScrollViewPullUp) {
            [self.scrollView removeObserver:self forKeyPath:@"contentSize" context:&KVOContext];
        }
        [self.observer willLeaveScrollView:(UIScrollView *)self.superview];
        self.observer = nil;
    }
}

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithDirection:0];
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &KVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    if ([keyPath isEqualToString:@"contentSize"]) {
        [self repositionWithinScrollView];
    }
}

static void * KVOContext = @"AwfulPullToRefreshControl KVO";

@end


@implementation ArrowView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _color = [UIColor lightGrayColor];
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGSize size = self.bounds.size;
    // Six rectangular segments for the shaft.
    // Each segment is half the width of this view and one twelfth the height.
    // There's a gap of half a segment between each.
    CGRect rects[6];
    CGFloat segmentHeight = floorf(size.height / 12);
    for (size_t i = 0; i < sizeof(rects) / sizeof(rects[0]); i++) {
        rects[i] = CGRectMake(floorf(size.width / 4), floorf(segmentHeight * 1.5 * i),
                              floorf(size.width / 2), segmentHeight);
    }
    CGContextAddRects(context, rects, sizeof(rects) / sizeof(rects[0]));
    // And a triangle for the head.
    // The triangle abuts the sixth segment of the shaft. It's as wide as this view and 3/10 the
    // height.
    CGContextMoveToPoint(context, 0, CGRectGetMaxY(rects[5]));
    CGContextAddLineToPoint(context, size.width, CGRectGetMaxY(rects[5]));
    CGContextAddLineToPoint(context, floorf(size.width / 2),
                            CGRectGetMaxY(rects[5]) + floorf(size.height * 0.3));
    CGContextClosePath(context);
    // Draw arrow with a gradient.
    CGContextClip(context);
    CGColorRef start = [self.color colorWithAlphaComponent:0].CGColor;
    CGColorRef end = self.color.CGColor;
    NSArray *colors = @[ (__bridge id)start, (__bridge id)end ];
    CGGradientRef gradient = CGGradientCreateWithColors(CGColorGetColorSpace(start),
                                                        (__bridge CFArrayRef)colors,
                                                        (CGFloat[]){ 0, 0.75 });
    CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0, size.height), 0);
    CGGradientRelease(gradient);
}


- (void)setRotation:(CGFloat)radians animated:(BOOL)animated
{
    [UIView animateWithDuration:(animated ? 0.2 : 0)
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^
    {
        self.transform = CGAffineTransformMakeRotation(radians);
    } completion:nil];
}

- (void)setColor:(UIColor *)color
{
    if (_color == color) return;
    _color = color;
    [self setNeedsDisplay];
}

@end
