//  AwfulImageCollectionViewCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulImageCollectionViewCell.h"
#import "AwfulThreadTagView.h"

@interface AwfulImageCollectionViewCell ()

@property (strong, nonatomic) AwfulThreadTagView *tagView;
@property (strong, nonatomic) UIImageView *selectedIcon;

@end

@implementation AwfulImageCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.tagView = [AwfulThreadTagView new];
    [self.contentView addSubview:self.tagView];
    UIImage *selectedTick = [UIImage imageNamed:@"selected-tick-icon"];
    self.selectedIcon = [[UIImageView alloc] initWithImage:selectedTick];
    self.selectedIcon.hidden = YES;
    [self.contentView addSubview:self.selectedIcon];
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

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    self.selectedIcon.hidden = !selected;
}

- (UIImage *)secondaryIcon
{
    return self.tagView.secondaryTagImage;
}

- (void)setSecondaryIcon:(UIImage *)secondaryIcon
{
    self.tagView.secondaryTagImage = secondaryIcon;
}

static const CGFloat kSelectedIconSize = 31;

- (void)layoutSubviews
{
    self.tagView.frame = self.bounds;
    self.selectedIcon.frame = CGRectMake(self.bounds.size.width-kSelectedIconSize,
                                         self.bounds.size.height-kSelectedIconSize,
                                         kSelectedIconSize, kSelectedIconSize);
}

@end
