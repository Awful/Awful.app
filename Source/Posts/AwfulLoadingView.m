//  AwfulLoadingView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulLoadingView.h"
#import "FVGifAnimation.h"

@interface AwfulDefaultLoadingView : AwfulLoadingView @end
@interface AwfulYOSPOSLoadingView : AwfulLoadingView @end
@interface AwfulMacinyosLoadingView : AwfulLoadingView @end
@interface AwfulWinpos95LoadingView : AwfulLoadingView @end

@interface AwfulLoadingView ()

@property (strong, nonatomic) AwfulTheme *theme;

- (void)retheme;

@end

@implementation AwfulLoadingView

+ (instancetype)loadingViewForTheme:(AwfulTheme *)theme
{
	AwfulLoadingView *loadingView;
	
	NSString *loadingViewTypeString = theme[@"postsLoadingViewType"];
	if ([loadingViewTypeString isEqualToString:@"Macinyos"]) {
		loadingView = [AwfulMacinyosLoadingView new];
	} else if ([loadingViewTypeString isEqualToString:@"Winpos95"]) {
		loadingView = [AwfulWinpos95LoadingView new];;
	} else if ([loadingViewTypeString isEqualToString:@"YOSPOS"]) {
		loadingView = [AwfulYOSPOSLoadingView new];
	} else {
		loadingView = [AwfulDefaultLoadingView new];
	}
	
	loadingView.theme = theme;
	
	return loadingView;
}

- (void)retheme
{
    // no-op
}

#pragma mark - UIView

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    self.frame = (CGRect){ .size = newSuperview.frame.size };
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self retheme];
}

@end

@interface AwfulDefaultLoadingView ()

@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@end

@implementation AwfulDefaultLoadingView

- (UIActivityIndicatorView *)spinner
{
    if (!_spinner) {
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_spinner];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:_spinner
                                      attribute:NSLayoutAttributeCenterX
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self
                                      attribute:NSLayoutAttributeCenterX
                                     multiplier:1
                                       constant:0]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:_spinner
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self
                                      attribute:NSLayoutAttributeCenterY
                                     multiplier:1
                                       constant:0]];
    }
    return _spinner;
}

- (void)retheme
{
    [super retheme];
	
	UIColor *tint = self.theme[@"postsLoadingViewTintColor"];
	
    self.backgroundColor = tint;
    self.spinner.backgroundColor = self.backgroundColor;
    CGFloat whiteness = 1;
    BOOL ok = [tint getWhite:&whiteness alpha:nil];
    if (!ok) {
        [tint getRed:&whiteness green:nil blue:nil alpha:nil];
    }
    if (whiteness < 0.5) {
        self.spinner.color = [UIColor whiteColor];
    } else {
        self.spinner.color = [UIColor grayColor];
    }
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    if (newSuperview) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
}

@end

@interface AwfulYOSPOSLoadingView ()

@property (strong, nonatomic) UILabel *ASCIISpinner;
@property (strong, nonatomic) NSTimer *spinnerTimer;

@end

@implementation AwfulYOSPOSLoadingView

- (void)dealloc
{
    [_spinnerTimer invalidate];
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor blackColor];
    }
    return self;
}

- (UILabel *)ASCIISpinner
{
    if (!_ASCIISpinner) {
        _ASCIISpinner = [UILabel new];
        _ASCIISpinner.translatesAutoresizingMaskIntoConstraints = NO;
        _ASCIISpinner.text = @"|";
        _ASCIISpinner.font = [UIFont fontWithName:@"Menlo" size:15];
        _ASCIISpinner.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_ASCIISpinner];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[spinner]|"
                                                 options:0
                                                 metrics:nil
                                                   views:@{@"spinner": _ASCIISpinner}]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:_ASCIISpinner
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self
                                      attribute:NSLayoutAttributeCenterY
                                     multiplier:1
                                       constant:0]];
    }
    return _ASCIISpinner;
}

- (void)retheme
{
    self.ASCIISpinner.textColor = self.theme[@"postsLoadingViewTintColor"];
    self.ASCIISpinner.backgroundColor = self.backgroundColor;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    if (newSuperview) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

- (void)startAnimating
{
    self.spinnerTimer = [NSTimer scheduledTimerWithTimeInterval:0.12
                                                         target:self
                                                       selector:@selector(spinnerTimerDidFire:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)spinnerTimerDidFire:(NSTimer *)timer
{
    [self advanceSpinner];
}

- (void)advanceSpinner
{
    NSString *state = self.ASCIISpinner.text;
    if ([state isEqualToString:@"/"]) {
        self.ASCIISpinner.text = @"-";
    } else if ([state isEqualToString:@"-"]) {
        self.ASCIISpinner.text = @"\\";
    } else if ([state isEqualToString:@"\\"]) {
        self.ASCIISpinner.text = @"|";
    } else {
        self.ASCIISpinner.text = @"/";
    }
}

- (void)stopAnimating
{
    [self.spinnerTimer invalidate];
    self.spinnerTimer = nil;
}

@end

@interface AwfulMacinyosLoadingView ()

@property (strong, nonatomic) UIImageView *finderImageView;

@end

@implementation AwfulMacinyosLoadingView

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"macinyos-wallpaper"]];
        
        _finderImageView = [UIImageView new];
        _finderImageView.image = [UIImage imageNamed:@"macinyos-loading"];
        _finderImageView.contentMode = UIViewContentModeCenter;
        _finderImageView.backgroundColor = [UIColor whiteColor];
        _finderImageView.layer.borderColor = [UIColor blackColor].CGColor;
        _finderImageView.layer.borderWidth = 1;
        [self insertSubview:_finderImageView atIndex:0];
    }
    return self;
}

- (void)layoutSubviews
{
    CGRect finderImageFrame = CGRectMake(0, 0, 300, 275);
    finderImageFrame.origin.x = CGRectGetMidX(self.bounds) - CGRectGetWidth(finderImageFrame) / 2;
    finderImageFrame.origin.y = CGRectGetMidY(self.bounds) - CGRectGetHeight(finderImageFrame) / 2;
    finderImageFrame = CGRectIntegral(finderImageFrame);
    self.finderImageView.frame = finderImageFrame;
}

@end

@interface AwfulWinpos95LoadingView ()

@property (strong, nonatomic) UIImageView *hourglassImageView;

@end

@implementation AwfulWinpos95LoadingView

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithRed:0.067 green:0.502 blue:0.502 alpha:1];
        
        _hourglassImageView = [UIImageView new];
        NSURL *gifURL = [[NSBundle mainBundle] URLForResource:@"hourglass" withExtension:@"gif"];
        FVGifAnimation *gif = [[FVGifAnimation alloc] initWithURL:gifURL];
        [gif setAnimationToImageView:_hourglassImageView];
        [self addSubview:_hourglassImageView];
        UIPanGestureRecognizer *pan = [UIPanGestureRecognizer new];
        [pan addTarget:self action:@selector(didPan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)didPan:(UIPanGestureRecognizer *)pan
{
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.hourglassImageView.center = [pan locationInView:self];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:self];
        self.hourglassImageView.frame = CGRectOffset(self.hourglassImageView.frame, translation.x, translation.y);
        [pan setTranslation:CGPointZero inView:self];
    }
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    if (newSuperview) {
        [self.hourglassImageView startAnimating];
    } else {
        [self.hourglassImageView stopAnimating];
    }
}

- (void)layoutSubviews
{
    [self.hourglassImageView sizeToFit];
    const CGFloat margin = 8;
    CGRect container = (CGRect){
        .size.width = CGRectGetWidth(self.hourglassImageView.frame) + margin,
        .size.height = CGRectGetHeight(self.hourglassImageView.frame),
    };
    container.origin.x = CGRectGetMidX(self.bounds) - CGRectGetWidth(container) / 2;
    container.origin.y = CGRectGetMidY(self.bounds) - CGRectGetHeight(container) / 2;
    container = CGRectIntegral(container);
    CGRect hourglassFrame, labelFrame;
    CGRectDivide(container, &hourglassFrame, &labelFrame, CGRectGetWidth(self.hourglassImageView.frame) + margin, CGRectMinXEdge);
    hourglassFrame.size.width -= margin;
    self.hourglassImageView.frame = hourglassFrame;
}

@end
