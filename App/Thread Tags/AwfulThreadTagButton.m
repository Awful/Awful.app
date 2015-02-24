//  AwfulThreadTagButton.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagButton.h"

@interface AwfulThreadTagButton ()

@property (strong, nonatomic) UIImageView *secondaryTagImageView;

@end

@implementation AwfulThreadTagButton

- (UIImage *)secondaryTagImage
{
    return self.secondaryTagImageView.image;
}

- (void)setSecondaryTagImage:(UIImage *)secondaryTagImage
{
    if (secondaryTagImage && !self.secondaryTagImageView) {
        self.secondaryTagImageView = [UIImageView new];
        self.secondaryTagImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.secondaryTagImageView];
        [self setNeedsUpdateConstraints];
    }
    UIImage *ensureRetina = [UIImage imageWithCGImage:secondaryTagImage.CGImage scale:2 orientation:secondaryTagImage.imageOrientation];
    self.secondaryTagImageView.image = ensureRetina;
}

- (void)updateConstraints
{
    if (self.secondaryTagImageView) {
        NSDictionary *views = @{ @"secondary": self.secondaryTagImageView };
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:[secondary]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:[secondary]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    }
    [super updateConstraints];
}

@end
