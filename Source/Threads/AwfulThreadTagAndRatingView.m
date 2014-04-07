//  AwfulThreadTagAndRatingView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagAndRatingView.h"

@implementation AwfulThreadTagAndRatingView
{
    UIImageView *_threadTagImageView;
    UIImageView *_secondaryThreadTagImageView;
    UIImageView *_ratingImageView;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _threadTagImageView = [UIImageView new];
    _threadTagImageView.contentMode = UIViewContentModeCenter;
    [self addSubview:_threadTagImageView];
    
    _secondaryThreadTagImageView = [UIImageView new];
    [_threadTagImageView addSubview:_secondaryThreadTagImageView];
    
    _ratingImageView = [UIImageView new];
    _ratingImageView.contentMode = UIViewContentModeCenter;
    [self addSubview:_ratingImageView];
    
    return self;
}

- (UIImage *)threadTagImage
{
    return _threadTagImageView.image;
}

- (void)setThreadTagImage:(UIImage *)threadTagImage
{
    _threadTagImageView.image = threadTagImage;
    [self setNeedsLayout];
}

- (UIImage *)secondaryThreadTagImage
{
    return _secondaryThreadTagImageView.image;
}

- (void)setSecondaryThreadTagImage:(UIImage *)secondaryThreadTagImage
{
    _secondaryThreadTagImageView.image = secondaryThreadTagImage;
    [self setNeedsLayout];
}

- (UIImage *)ratingImage
{
    return _ratingImageView.image;
}

- (void)setRatingImage:(UIImage *)ratingImage
{
    _ratingImageView.image = ratingImage;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [_threadTagImageView sizeToFit];
    [_ratingImageView sizeToFit];
    [_secondaryThreadTagImageView sizeToFit];
    
    CGFloat totalHeight = CGRectGetHeight(_threadTagImageView.bounds);
    if (_ratingImageView.image) {
        totalHeight += 2 + CGRectGetHeight(_ratingImageView.bounds);
    }
    CGRect workingRect = CGRectInset(self.bounds, 0, (CGRectGetHeight(self.bounds) - totalHeight) / 2);
    workingRect = CGRectIntegral(workingRect);
    
    CGRect tagFrame = _threadTagImageView.bounds;
    tagFrame.origin.y = CGRectGetMinY(workingRect);
    tagFrame.size.width = CGRectGetWidth(workingRect);
    _threadTagImageView.frame = tagFrame;
    
    if (_ratingImageView.image) {
        CGRect ratingFrame = _ratingImageView.bounds;
        ratingFrame.origin.y = CGRectGetMaxY(workingRect) - CGRectGetHeight(ratingFrame);
        ratingFrame.size.width = CGRectGetWidth(workingRect);
        _ratingImageView.frame = ratingFrame;
    }
    
    if (_secondaryThreadTagImageView.image) {
        CGRect secondaryFrame = _secondaryThreadTagImageView.bounds;
        CGRect tagBounds = _threadTagImageView.bounds;
        secondaryFrame.origin.x = CGRectGetMaxX(tagBounds) - CGRectGetWidth(secondaryFrame) + 1;
        secondaryFrame.origin.y += CGRectGetMaxY(tagBounds) - CGRectGetHeight(secondaryFrame) + 1;
        _secondaryThreadTagImageView.frame = secondaryFrame;
    }
}

@end
