//  AwfulThreadTagView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagView.h"

@interface AwfulThreadTagView ()

@property (strong, nonatomic) UIImageView *tagImageView;
@property (strong, nonatomic) UIImageView *secondaryTagImageView;

@end

@implementation AwfulThreadTagView

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.tagImageView = [UIImageView new];
        self.tagImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.tagImageView];
        
        NSDictionary *views = @{ @"tag": self.tagImageView };
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tag]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tag]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    }
    return self;
}

- (UIImage *)tagImage
{
    return self.tagImageView.image;
}

- (void)setTagImage:(UIImage *)tagImage
{
    self.tagImageView.image = tagImage;
}

- (void)setTagBorderColor:(UIColor *)borderColor width:(CGFloat)width
{
    if (borderColor && width > 0) {
        self.tagImageView.layer.borderColor = borderColor.CGColor;
        self.tagImageView.layer.borderWidth = width;
    } else {
        self.tagImageView.layer.borderColor = nil;
        self.tagImageView.layer.borderWidth = 0;
    }
}

- (UIImage *)secondaryTagImage
{
    return self.secondaryTagImageView.image;
}

- (void)setSecondaryTagImage:(UIImage *)secondaryTagImage
{
    if (secondaryTagImage) {
        if (!self.secondaryTagImageView) {
            self.secondaryTagImageView = [UIImageView new];
            self.secondaryTagImageView.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:self.secondaryTagImageView];
            [self setNeedsUpdateConstraints];
        }
        UIImage *ensureRetina = [UIImage imageWithCGImage:secondaryTagImage.CGImage scale:2 orientation:secondaryTagImage.imageOrientation];
        self.secondaryTagImageView.image = ensureRetina;
    } else {
        [self.secondaryTagImageView removeFromSuperview];
        self.secondaryTagImageView = nil;
    }
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
