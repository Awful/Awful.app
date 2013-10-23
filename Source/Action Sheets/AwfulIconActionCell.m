//  AwfulIconActionCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulIconActionCell.h"

@interface AwfulIconActionCell ()

@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIImageView *imageView;

@end

@implementation AwfulIconActionCell

- (NSString *)title
{
    return self.titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    self.titleLabel.text = title;
}

- (void)setIcon:(UIImage *)icon
{
    if (_icon == icon) return;
    _icon = icon;
    [self updateImage];
}

- (void)setTintColor:(UIColor *)tintColor
{
    if (_tintColor == tintColor) return;
    _tintColor = tintColor;
    [self updateImage];
}

- (void)updateImage
{
    if (!self.tintColor) {
        self.imageView.image = nil;
        self.imageView.highlightedImage = nil;
        return;
    }
    
    void (^drawIcon)(void) = ^{
        if (self.icon) {
            CGRect rect = (CGRect){ .size = self.icon.size };
            rect.origin.x = (ImageSize.width - CGRectGetWidth(rect)) / 2;
            rect.origin.y = (ImageSize.height - CGRectGetHeight(rect)) / 2;
            [self.icon drawInRect:rect];
        }
    };
    
    UIGraphicsBeginImageContextWithOptions(ImageSize, NO, 0);
    
    [self.tintColor set];
  
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:(CGRect){ .size = ImageSize }];
    path.lineWidth = 2;
    [path addClip];
    
    [path stroke];
    drawIcon();
    self.imageView.highlightedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    [path fill];
    drawIcon();
    self.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
}

const CGSize ImageSize = {56, 56};

#pragma mark - UICollectionViewCell

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    self.imageView.highlighted = highlighted;
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.titleLabel = [UILabel new];
    self.titleLabel.backgroundColor = nil;
    self.titleLabel.font = [UIFont systemFontOfSize:12];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.titleLabel];
    self.imageView = [UIImageView new];
    [self.contentView addSubview:self.imageView];
    return self;
}

- (void)layoutSubviews
{
    CGRect imageFrame, titleFrame;
    CGRectDivide(self.contentView.bounds, &imageFrame, &titleFrame, ImageSize.width, CGRectMinYEdge);
    imageFrame.origin.x += (CGRectGetWidth(imageFrame) - ImageSize.width) / 2;
    imageFrame.size.width = ImageSize.width;
    self.imageView.frame = imageFrame;
    self.titleLabel.frame = titleFrame;
    [self.titleLabel sizeToFit];
    titleFrame.size.height = CGRectGetHeight(self.titleLabel.frame);
    self.titleLabel.frame = titleFrame;
}

@end
