//  AwfulThreadTagAndRatingView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagAndRatingView.h"

@implementation AwfulThreadTagAndRatingView
{
    UIImageView *_tagImageView;
    UIImageView *_ratingImageView;
    CGFloat _gap;
    BOOL _addedInitialConstraints;
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _tagImageView = [UIImageView new];
    _tagImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_tagImageView];
    
    _secondaryThreadTagBadge = [UILabel new];
    _secondaryThreadTagBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _secondaryThreadTagBadge.layer.cornerRadius = badgeRadius;
    _secondaryThreadTagBadge.clipsToBounds = YES;
    _secondaryThreadTagBadge.font = [UIFont systemFontOfSize:10];
    _secondaryThreadTagBadge.textAlignment = NSTextAlignmentCenter;
    _secondaryThreadTagBadge.textColor = [UIColor whiteColor];
    [_tagImageView addSubview:_secondaryThreadTagBadge];
    return self;
}

static const CGFloat badgeRadius = 7;

- (void)updateConstraints
{
    if (!_addedInitialConstraints) {
        NSDictionary *views = @{ @"tag": _tagImageView,
                                 @"secondary": _secondaryThreadTagBadge };
        NSDictionary *metrics = @{ @"badgeWidth": @(badgeRadius * 2) };
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tag]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tag]-0@500-|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [_tagImageView addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:[secondary(badgeWidth)]|"
                                                 options:0
                                                 metrics:metrics
                                                   views:views]];
        [_tagImageView addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:[secondary(badgeWidth)]|"
                                                 options:0
                                                 metrics:metrics
                                                   views:views]];
        _addedInitialConstraints = YES;
    }
    if (_ratingImageView) {
        NSDictionary *views = @{ @"tag": _tagImageView,
                                 @"rating": _ratingImageView };
        NSDictionary *metrics = @{ @"gap": @(_gap) };
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tag]-gap-[rating]|"
                                                 options:0
                                                 metrics:metrics
                                                   views:views]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:views[@"rating"]
                                      attribute:NSLayoutAttributeCenterX
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:views[@"tag"]
                                      attribute:NSLayoutAttributeCenterX
                                     multiplier:1
                                       constant:0]];
    }
    [super updateConstraints];
}

- (UIImage *)threadTag
{
    return _tagImageView.image;
}

- (void)setThreadTag:(UIImage *)threadTag
{
    _tagImageView.image = threadTag;
    [self invalidateIntrinsicContentSize];
}

- (UIImage *)ratingImage
{
    return _ratingImageView.image;
}

- (void)setRatingImage:(UIImage *)ratingImage
{
    if (ratingImage && !_ratingImageView) {
        _ratingImageView = [[UIImageView alloc] initWithImage:ratingImage];
        _ratingImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _gap = 2;
        [self addSubview:_ratingImageView];
        [self setNeedsUpdateConstraints];
    } else if (!ratingImage && _ratingImageView) {
        [_ratingImageView removeFromSuperview];
        _ratingImageView = nil;
    }
}

- (CGSize)intrinsicContentSize
{
    CGSize size = _tagImageView.intrinsicContentSize;
    if (_ratingImageView) {
        size.height += _gap + _ratingImageView.intrinsicContentSize.height;
    }
    return size;
}

@end
