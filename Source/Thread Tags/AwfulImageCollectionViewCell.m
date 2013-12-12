//  AwfulImageCollectionViewCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulImageCollectionViewCell.h"
#import "AwfulThreadTagView.h"

@interface AwfulImageCollectionViewCell ()

@property (strong, nonatomic) AwfulThreadTagView *tagView;

@end

@implementation AwfulImageCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.tagView = [AwfulThreadTagView new];
    [self.contentView addSubview:self.tagView];
    return self;
}

- (UIImage *)icon
{
    return self.tagView.tagImage;
}

- (void)setIcon:(UIImage *)icon
{
    self.tagView.tagImage = icon;
}

- (UIImage *)secondaryIcon
{
    return self.tagView.secondaryTagImage;
}

- (void)setSecondaryIcon:(UIImage *)secondaryIcon
{
    self.tagView.secondaryTagImage = secondaryIcon;
}

- (void)layoutSubviews
{
    self.tagView.frame = CGRectInset(self.bounds, 2, 2);
}

@end
