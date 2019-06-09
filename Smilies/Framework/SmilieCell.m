//  SmilieCell.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieCell.h"
#import "SmilieCollectionViewFlowLayout.h"

@interface SmilieCell ()

@property (strong, nonatomic) UIImageView *removeControl;
@property (strong, nonatomic) FLAnimatedImageView *imageView;
@property (strong, nonatomic) UILabel *textLabel;

@end

@implementation SmilieCell

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.contentView.clipsToBounds = YES;
        self.contentView.layer.cornerRadius = 5;
        self.layer.shadowOpacity = 1;
        self.layer.shadowOffset = CGSizeMake(0, 1);
        self.layer.shadowRadius = 0;
        self.layer.shadowColor = [UIColor lightGrayColor].CGColor;
        
        self.accessibilityTraits |= UIAccessibilityTraitKeyboardKey;
    }
    return self;
}

- (void)setEditing:(BOOL)editing
{
    _editing = editing;
    self.removeControl.hidden = !editing;
    if (editing) {
        [self startWobbling];
    } else {
        [self stopWobbling];
    }
}

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityHint
{
    return self.editing ? @"Double-tap to remove" : super.accessibilityHint;
}

- (UIImageView *)removeControl
{
    if (!_removeControl) {
        UIImage *image = [UIImage imageNamed:@"remove" inBundle:[NSBundle bundleForClass:[SmilieCell class]] compatibleWithTraitCollection:nil];
        _removeControl = [[UIImageView alloc] initWithImage:image];
        _removeControl.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_removeControl];
        
        const CGFloat inset = 6;
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:_removeControl
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeTop
                                     multiplier:1
                                       constant:inset]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:_removeControl
                                      attribute:NSLayoutAttributeCenterX
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeLeft
                                     multiplier:1
                                       constant:inset]];
    }
    return _removeControl;
}

- (FLAnimatedImageView *)imageView
{
    if (!_imageView) {
        _imageView = [FLAnimatedImageView new];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_imageView];
        
        [self.contentView addConstraint:
         [NSLayoutConstraint constraintWithItem:_imageView
                                      attribute:NSLayoutAttributeCenterX
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeCenterX
                                     multiplier:1
                                       constant:0]];
        [self.contentView addConstraint:
         [NSLayoutConstraint constraintWithItem:_imageView
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeCenterY
                                     multiplier:1
                                       constant:0]];
    }
    return _imageView;
}

- (UILabel *)textLabel
{
    if (!_textLabel) {
        _textLabel = [UILabel new];
        _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_textLabel];
        
        _textLabel.font = [[self class] textLabelFont];
        _textLabel.textAlignment = NSTextAlignmentCenter;
        
        UIEdgeInsets insets = [[self class] textLabelInsets];
        [self.contentView addConstraint:
         [NSLayoutConstraint constraintWithItem:_textLabel
                                      attribute:NSLayoutAttributeLeading
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeLeading
                                     multiplier:1
                                       constant:insets.left]];
        [self.contentView addConstraint:
         [NSLayoutConstraint constraintWithItem:self.contentView
                                      attribute:NSLayoutAttributeTrailing
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:_textLabel
                                      attribute:NSLayoutAttributeTrailing
                                     multiplier:1
                                       constant:insets.right]];
        [_textLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [self.contentView addConstraint:
         [NSLayoutConstraint constraintWithItem:_textLabel
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeCenterY
                                     multiplier:1
                                       constant:0]];
    }
    return _textLabel;
}

+ (UIFont *)textLabelFont
{
    return [UIFont systemFontOfSize:12];
}

+ (UIEdgeInsets)textLabelInsets
{
    return (UIEdgeInsets){.left = 3, .right = 3};
}

- (void)setNormalBackgroundColor:(UIColor *)normalBackgroundColor
{
    _normalBackgroundColor = normalBackgroundColor;
    [self updateBackgroundColor];
}

- (void)setSelectedBackgroundColor:(UIColor *)selectedBackgroundColor
{
    _selectedBackgroundColor = selectedBackgroundColor;
    [self updateBackgroundColor];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateBackgroundColor];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self updateBackgroundColor];
}

- (void)updateBackgroundColor
{
    if (self.highlighted || self.selected) {
        self.contentView.backgroundColor = self.selectedBackgroundColor;
    } else {
        self.contentView.backgroundColor = self.normalBackgroundColor;
    }
}

- (void)startWobbling
{
    if (![self.layer animationForKey:@"wobble"]) {
        self.layer.anchorPoint = CGPointMake(0.5, 0.5);
        
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
        animation.duration = 0.2;
        CGFloat degrees = (CGFloat)(1 + arc4random_uniform(500) / 500.0 + 0.5);
        
        // Randomize the start direction. It looks weird when all the cells rotate the same way.
        degrees *= arc4random_uniform(1) ? -1 : 1;
        
        animation.values = @[@0, @(degrees * M_PI / 180), @0, @(-degrees * M_PI / 180), @0];
        animation.repeatCount = HUGE_VALF;
        [self.layer addAnimation:animation forKey:@"wobble"];
    }
}

- (void)stopWobbling
{
    [self.layer removeAnimationForKey:@"wobble"];
}

- (void)applyLayoutAttributes:(SmilieCollectionViewFlowLayoutAttributes *)attributes
{
    [super applyLayoutAttributes:attributes];
    if ([attributes isKindOfClass:[SmilieCollectionViewFlowLayoutAttributes class]]) {
        self.editing = attributes.editing;
    }
}

@end
