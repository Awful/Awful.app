//
//  AwfulImageCollectionViewCell.m
//  Awful
//
//  Created by Nolan Waite on 2013-03-04.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
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
