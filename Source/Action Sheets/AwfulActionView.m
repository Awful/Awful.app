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
    UILabel *_titleLabel;
    UICollectionViewFlowLayout *_collectionViewLayout;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    self.titleLabel = [UILabel new];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.backgroundColor = [UIColor colorWithWhite:0.086 alpha:1];
    self.titleLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    [self addSubview:self.titleLabel];
    
    _collectionViewLayout = [UICollectionViewFlowLayout new];
    _collectionViewLayout.itemSize = CGSizeMake(70, 90);
    _collectionViewLayout.sectionInset = UIEdgeInsetsMake(12, 0, 12, 0);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:_collectionViewLayout];
    self.collectionView.backgroundColor = [UIColor colorWithWhite:0.047 alpha:1];
    [self addSubview:self.collectionView];
    
    self.backgroundColor = self.collectionView.backgroundColor;
    return self;
}

- (void)layoutSubviews
{
    CGRect bounds = self.bounds;
    CGRect titleFrame = CGRectMake(0, 0, CGRectGetWidth(bounds), 0);
    _titleLabel.frame = titleFrame;
    [_titleLabel sizeToFit];
    CGFloat desiredHeight = CGRectGetHeight(_titleLabel.frame);
    if (desiredHeight > 0) {
        titleFrame.size.height = desiredHeight + 16;
    }
    _titleLabel.frame = titleFrame;
    
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

- (void)sizeToFit
{
    [self layoutIfNeeded];
    CGRect bounds = self.bounds;
    bounds.size.height = CGRectGetMaxY(self.collectionView.frame);
    self.bounds = bounds;
}

@end
