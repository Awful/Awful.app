//
//  AwfulImageCollectionViewCell.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulImageCollectionViewCell.h"

@implementation AwfulImageCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _imageView = [UIImageView new];
    [self.contentView addSubview:_imageView];
    return self;
}

- (void)layoutSubviews
{
    self.imageView.frame = CGRectInset((CGRect){ .size = self.frame.size }, 2, 2);
}

@end
