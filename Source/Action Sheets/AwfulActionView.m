//  AwfulActionView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulActionView.h"

@interface AwfulActionView ()

@property (strong, nonatomic) UILabel *titleLabel;

@property (strong, nonatomic) UICollectionView *collectionView;

@end

@implementation AwfulActionView
{
    UIView *_titleBackgroundView;
    UICollectionViewFlowLayout *_collectionViewLayout;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _titleBackgroundView = [UIView new];
    [self addSubview:_titleBackgroundView];
    
    self.titleLabel = [UILabel new];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    [_titleBackgroundView addSubview:self.titleLabel];
    
    self.titleBackgroundColor = [UIColor colorWithWhite:0.086 alpha:1];
    
    _collectionViewLayout = [UICollectionViewFlowLayout new];
    _collectionViewLayout.itemSize = CGSizeMake(70, 90);
    _collectionViewLayout.sectionInset = UIEdgeInsetsMake(12, 0, 12, 0);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:_collectionViewLayout];
    [self addSubview:self.collectionView];
    
    self.backgroundColor = [UIColor colorWithWhite:0.047 alpha:1];
    
    return self;
}

static const CGSize titleMargin = {32, 0};

- (void)layoutSubviews
{
    CGRect bounds = self.bounds;
    CGRect titleFrame = CGRectMake(titleMargin.width, 0, CGRectGetWidth(bounds) - titleMargin.width * 2, 0);
    _titleLabel.frame = titleFrame;
    [_titleLabel sizeToFit];
    CGFloat desiredHeight = CGRectGetHeight(_titleLabel.frame);
    if (desiredHeight > 0) {
        titleFrame.size.height = desiredHeight + 16;
    }
    _titleLabel.frame = titleFrame;
    _titleBackgroundView.frame = CGRectMake(0, 0, CGRectGetWidth(bounds), CGRectGetHeight(titleFrame));
    
    CGRect gridFrame = CGRectMake(0, CGRectGetMaxY(_titleLabel.frame), CGRectGetWidth(bounds), 0);
    self.collectionView.frame = gridFrame;
    CGSize contentSize = _collectionViewLayout.collectionViewContentSize;
    gridFrame.size.height = contentSize.height;
    
    // Center the icons if they'll all fit on one row.
    NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    CGRect firstItemFrame = [_collectionViewLayout layoutAttributesForItemAtIndexPath:firstIndexPath].frame;
    NSInteger numberOfItems = [self.collectionView.dataSource collectionView:self.collectionView numberOfItemsInSection:0];
    NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:numberOfItems - 1 inSection:0];
    CGRect lastItemFrame = [_collectionViewLayout layoutAttributesForItemAtIndexPath:lastIndexPath].frame;
    if (CGRectGetMinY(firstItemFrame) == CGRectGetMinY(lastItemFrame)) {
        gridFrame.size.width = CGRectGetMaxX(lastItemFrame);
        gridFrame.origin.x = CGRectGetMidX(bounds) - CGRectGetWidth(gridFrame) / 2;
    }
    
    self.collectionView.frame = gridFrame;
}

- (CGSize)sizeThatFits:(CGSize)size
{
    [self layoutIfNeeded];
    return CGSizeMake(size.width, CGRectGetMaxY(self.collectionView.frame));
}

- (UIColor *)titleBackgroundColor
{
    return _titleBackgroundView.backgroundColor;
}

- (void)setTitleBackgroundColor:(UIColor *)titleBackgroundColor
{
    _titleBackgroundView.backgroundColor = titleBackgroundColor;
    self.titleLabel.backgroundColor = titleBackgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    self.collectionView.backgroundColor = backgroundColor;
}

@end
