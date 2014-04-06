//  AwfulThreadTagAndRatingView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagAndRatingView.h"

@implementation AwfulThreadTagAndRatingView
{
    UIImageView *_tagImageView;
    UIImageView *_secondaryTagImageView;
    UIImageView *_ratingImageView;
    CGFloat _gap;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _tagImageView = [UIImageView new];
    _tagImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_tagImageView];
    
    _secondaryTagImageView = [UIImageView new];
    _secondaryTagImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_secondaryTagImageView];
    
    NSDictionary *views = @{ @"tag": _tagImageView,
                             @"secondary": _secondaryTagImageView };
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
    [self addConstraint:
     [NSLayoutConstraint constraintWithItem:_secondaryTagImageView
                                  attribute:NSLayoutAttributeRight
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:_tagImageView
                                  attribute:NSLayoutAttributeRight
                                 multiplier:1
                                   constant:1]];
    [self addConstraint:
     [NSLayoutConstraint constraintWithItem:_secondaryTagImageView
                                  attribute:NSLayoutAttributeBottom
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:_tagImageView
                                  attribute:NSLayoutAttributeBottom
                                 multiplier:1
                                   constant:1]];
    return self;
}

- (void)updateConstraints
{
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

- (UIImage *)secondaryThreadTag
{
    return _secondaryTagImageView.image;
}

- (void)setSecondaryThreadTag:(UIImage *)secondaryThreadTag
{
    UIImage *ensureRetina = [UIImage imageWithCGImage:secondaryThreadTag.CGImage scale:2 orientation:secondaryThreadTag.imageOrientation];
    _secondaryTagImageView.image = ensureRetina;
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
