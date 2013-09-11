//
//  AwfulThreadTagAndRatingView.m
//  Awful
//
//  Created by Nolan Waite on 2013-09-10.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

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
    if (!(self = [super initWithFrame:frame])) return nil;
    _tagImageView = [UIImageView new];
    _tagImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_tagImageView];
    _secondaryTagImageView = [UIImageView new];
    _secondaryTagImageView.translatesAutoresizingMaskIntoConstraints = NO;
//    [_tagImageView addSubview:_secondaryTagImageView];

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
//    [_tagImageView addConstraints:
//     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[secondary]|"
//                                             options:0
//                                             metrics:nil
//                                               views:views]];
//    [_tagImageView addConstraints:
//     [NSLayoutConstraint constraintsWithVisualFormat:@"V:[secondary]|"
//                                             options:0
//                                             metrics:nil
//                                               views:views]];
    return self;
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
    _secondaryTagImageView.image = secondaryThreadTag;
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
        _gap = 1;
        [self addSubview:_ratingImageView];
        [self setNeedsUpdateConstraints];
    } else if (!ratingImage && _ratingImageView) {
        [_ratingImageView removeFromSuperview];
        _ratingImageView = nil;
    }
}

- (void)updateConstraints
{
    [super updateConstraints];
    if (_ratingImageView) {
        NSDictionary *views = @{ @"tag": _tagImageView,
                                 @"rating": _ratingImageView };
        NSDictionary *metrics = @{ @"gap": @(_gap) };
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tag]-gap-[rating]|"
                                                 options:0
                                                 metrics:metrics
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[rating(tag)]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    }
}

- (CGSize)intrinsicContentSize
{
    CGSize size = _tagImageView.intrinsicContentSize;
    if (_ratingImageView) {
        size.height += 1 + _ratingImageView.intrinsicContentSize.height;
    }
    return size;
}

@end
