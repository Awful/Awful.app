//  SmilieCell.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieCell.h"

@interface SmilieCell ()

@property (strong, nonatomic) FLAnimatedImageView *imageView;

@end

@implementation SmilieCell

- (FLAnimatedImageView *)imageView
{
    if (!_imageView) {
        _imageView = [FLAnimatedImageView new];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [_imageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_imageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [_imageView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_imageView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [self.contentView addSubview:_imageView];
        
        NSDictionary *views = @{@"image": _imageView};
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[image]|" options:0 metrics:nil views:views]];
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[image]|" options:0 metrics:nil views:views]];
    }
    return _imageView;
}

@end
