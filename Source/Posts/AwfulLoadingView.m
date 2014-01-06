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
@property (strong, nonatomic) UILabel *messageLabel;

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

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.messageLabel = [UILabel new];
    self.messageLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [self addSubview:self.messageLabel];
    return self;
}

- (NSString *)message
{
    return self.messageLabel.text;
}

- (void)setMessage:(NSString *)message
{
    self.messageLabel.text = message;
    [self setNeedsLayout];
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

@implementation AwfulDefaultLoadingView
{
    UIActivityIndicatorView *_spinner;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _spinner = [UIActivityIndicatorView new];
    [self addSubview:_spinner];
    return self;
}

- (void)retheme
{
    [super retheme];
	
	UIColor *tint = self.theme[@"postsLoadingViewTintColor"];
	
    self.backgroundColor = tint;
    _spinner.backgroundColor = self.backgroundColor;
    CGFloat whiteness = 1;
    BOOL ok = [tint getWhite:&whiteness alpha:nil];
    if (!ok) {
        [tint getRed:&whiteness green:nil blue:nil alpha:nil];
    }
    if (whiteness < 0.1) {
        _spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
        self.messageLabel.textColor = [UIColor colorWithWhite:0.95 alpha:1];
        self.messageLabel.shadowColor = nil;
    } else {
        _spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.messageLabel.textColor = [UIColor blackColor];
    }
    self.messageLabel.backgroundColor = self.backgroundColor;
}

#pragma mark - UIView

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    if (newSuperview) {
        [_spinner startAnimating];
    } else {
        [_spinner stopAnimating];
    }
}

- (void)layoutSubviews
{
    [self.messageLabel sizeToFit];
    const CGFloat spinnerWidth = 14;
    const CGFloat margin = 8;
    CGRect container = (CGRect){
        .size.width = CGRectGetWidth(self.messageLabel.frame) + margin + spinnerWidth,
        .size.height = MAX(spinnerWidth, CGRectGetHeight(self.messageLabel.frame)),
    };
    container.origin.x = (CGRectGetWidth(self.bounds) - CGRectGetWidth(container)) / 2;
    container.origin.y = CGRectGetMidY(self.bounds) - CGRectGetHeight(container) / 2;
    container = CGRectIntegral(container);
    CGRect spinnerFrame, labelFrame;
    CGRectDivide(container, &spinnerFrame, &labelFrame, spinnerWidth + margin, CGRectMinXEdge);
    spinnerFrame.size.width -= margin;
    _spinner.frame = spinnerFrame;
    self.messageLabel.frame = labelFrame;
}

@end

@implementation AwfulYOSPOSLoadingView
{
    UILabel *_ASCIISpinner;
    NSTimer *_spinnerTimer;
}

- (void)dealloc
{
    [_spinnerTimer invalidate];
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = [UIColor blackColor];
    
    _ASCIISpinner = [UILabel new];
    _ASCIISpinner.font = [UIFont fontWithName:@"Menlo" size:15];
    _ASCIISpinner.backgroundColor = self.backgroundColor;
    [self advanceSpinner];
    [self addSubview:_ASCIISpinner];
    
    self.messageLabel.backgroundColor = self.backgroundColor;
    self.messageLabel.font = [UIFont fontWithName:@"Menlo" size:13];
    return self;
}

- (void)advanceSpinner
{
    NSString *state = _ASCIISpinner.text;
    if ([state isEqualToString:@"/"]) {
        _ASCIISpinner.text = @"-";
    } else if ([state isEqualToString:@"-"]) {
        _ASCIISpinner.text = @"\\";
    } else if ([state isEqualToString:@"\\"]) {
        _ASCIISpinner.text = @"|";
    } else {
        _ASCIISpinner.text = @"/";
    }
}

- (void)retheme
{
    self.messageLabel.textColor = self.theme[@"postsLoadingViewTintColor"];
    _ASCIISpinner.textColor = self.theme[@"postsLoadingViewTintColor"];
}

#pragma mark - UIView

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
    _spinnerTimer = [NSTimer scheduledTimerWithTimeInterval:0.12
                                                     target:self
                                                   selector:@selector(spinnerTimerDidFire:)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)spinnerTimerDidFire:(NSTimer *)timer
{
    [self advanceSpinner];
}

- (void)stopAnimating
{
    [_spinnerTimer invalidate];
    _spinnerTimer = nil;
}

- (void)layoutSubviews
{
    [_ASCIISpinner sizeToFit];
    [self.messageLabel sizeToFit];
    const CGFloat margin = 8;
    CGRect container = (CGRect){
        .size.width = (CGRectGetWidth(_ASCIISpinner.frame) + margin + CGRectGetWidth(self.messageLabel.frame)),
        .size.height = CGRectGetHeight(_ASCIISpinner.frame),
    };
    container.origin.x = CGRectGetMidX(self.bounds) - CGRectGetWidth(container) / 2;
    container.origin.y = CGRectGetMidY(self.bounds) - CGRectGetHeight(container) / 2;
    container = CGRectIntegral(container);
    CGRect spinnerFrame, labelFrame;
    CGRectDivide(container, &spinnerFrame, &labelFrame, CGRectGetWidth(_ASCIISpinner.frame) + margin, CGRectMinXEdge);
    spinnerFrame.size.width -= margin;
    _ASCIISpinner.frame = spinnerFrame;
    self.messageLabel.frame = labelFrame;
}

@end

@implementation AwfulMacinyosLoadingView
{
    UIImageView *_finderImageView;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"macinyos-wallpaper"]];
    
    _finderImageView = [UIImageView new];
    _finderImageView.image = [UIImage imageNamed:@"macinyos-loading"];
    _finderImageView.contentMode = UIViewContentModeCenter;
    _finderImageView.backgroundColor = [UIColor whiteColor];
    _finderImageView.layer.borderColor = [UIColor blackColor].CGColor;
    _finderImageView.layer.borderWidth = 1;
    [self insertSubview:_finderImageView atIndex:0];
    
    self.messageLabel.font = [UIFont fontWithName:@"GeezaPro" size:15];
    self.messageLabel.backgroundColor = _finderImageView.backgroundColor;
    return self;
}

#pragma mark - UIView

- (void)layoutSubviews
{
    CGRect finderImageFrame = CGRectMake(0, 0, 300, 275);
    finderImageFrame.origin.x = CGRectGetMidX(self.bounds) - CGRectGetWidth(finderImageFrame) / 2;
    finderImageFrame.origin.y = CGRectGetMidY(self.bounds) - CGRectGetHeight(finderImageFrame) / 2;
    finderImageFrame = CGRectIntegral(finderImageFrame);
    _finderImageView.frame = finderImageFrame;
    CGFloat bottomMargin = (CGRectGetHeight(finderImageFrame) - _finderImageView.image.size.height) / 2;
    [self.messageLabel sizeToFit];
    self.messageLabel.center = CGPointMake(CGRectGetMidX(finderImageFrame), CGRectGetMaxY(finderImageFrame) - bottomMargin / 2);
}

@end

@implementation AwfulWinpos95LoadingView
{
    UIImageView *_hourglassImageView;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor colorWithRed:0.067 green:0.502 blue:0.502 alpha:1];
    
    _hourglassImageView = [UIImageView new];
    NSURL *gifURL = [[NSBundle mainBundle] URLForResource:@"hourglass" withExtension:@"gif"];
    FVGifAnimation *gif = [[FVGifAnimation alloc] initWithURL:gifURL];
    [gif setAnimationToImageView:_hourglassImageView];
    [self addSubview:_hourglassImageView];
    UIPanGestureRecognizer *pan = [UIPanGestureRecognizer new];
    [pan addTarget:self action:@selector(didPan:)];
    [self addGestureRecognizer:pan];
    
    self.messageLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:13];
    self.messageLabel.backgroundColor = self.backgroundColor;
    return self;
}

- (void)didPan:(UIPanGestureRecognizer *)pan
{
    if (pan.state == UIGestureRecognizerStateBegan) {
        _hourglassImageView.center = [pan locationInView:self];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:self];
        _hourglassImageView.frame = CGRectOffset(_hourglassImageView.frame, translation.x, translation.y);
        [pan setTranslation:CGPointZero inView:self];
    }
}

#pragma mark - UIView

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    if (newSuperview) {
        [_hourglassImageView startAnimating];
    } else {
        [_hourglassImageView stopAnimating];
    }
}

- (void)layoutSubviews
{
    [_hourglassImageView sizeToFit];
    [self.messageLabel sizeToFit];
    const CGFloat margin = 8;
    CGRect container = (CGRect){
        .size.width = (CGRectGetWidth(_hourglassImageView.frame) + margin + CGRectGetWidth(self.messageLabel.frame)),
        .size.height = CGRectGetHeight(_hourglassImageView.frame),
    };
    container.origin.x = CGRectGetMidX(self.bounds) - CGRectGetWidth(container) / 2;
    container.origin.y = CGRectGetMidY(self.bounds) - CGRectGetHeight(container) / 2;
    container = CGRectIntegral(container);
    CGRect hourglassFrame, labelFrame;
    CGRectDivide(container, &hourglassFrame, &labelFrame, CGRectGetWidth(_hourglassImageView.frame) + margin, CGRectMinXEdge);
    hourglassFrame.size.width -= margin;
    _hourglassImageView.frame = hourglassFrame;
    self.messageLabel.frame = labelFrame;
}

@end
