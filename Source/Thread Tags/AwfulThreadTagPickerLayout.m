//  AwfulThreadTagPickerLayout.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagPickerLayout.h"

@interface AwfulThreadTagPickerLayout ()

@property (readonly, assign, nonatomic) BOOL pickerHasSecondaryTags;
@property (assign, nonatomic) CGFloat centeringOffset;

@end

@implementation AwfulThreadTagPickerLayout

- (BOOL)pickerHasSecondaryTags
{
    return self.collectionView.numberOfSections > 1;
}

- (CGFloat)centeringOffset
{
    if (_centeringOffset == 0 && self.pickerHasSecondaryTags) {
        UICollectionViewLayoutAttributes *firstAttributes = [super layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        UICollectionViewLayoutAttributes *lastAttributes = [super layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:[self.collectionView numberOfItemsInSection:0] - 1 inSection:0]];
        CGFloat sectionWidth = CGRectGetWidth(CGRectUnion(firstAttributes.frame, lastAttributes.frame));
        _centeringOffset = (self.collectionViewContentSize.width - sectionWidth) / 2;
    }
    return _centeringOffset;
}

- (void)invalidateLayout
{
    self.centeringOffset = 0;
    [super invalidateLayout];
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context
{
    self.centeringOffset = 0;
    [super invalidateLayoutWithContext:context];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = [super layoutAttributesForItemAtIndexPath:indexPath];
    if (indexPath.section == 0 && self.pickerHasSecondaryTags) {
        attributes.frame = CGRectOffset(attributes.frame, self.centeringOffset, 0);
    }
    return attributes;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSArray *attributeses = [super layoutAttributesForElementsInRect:rect];
    if (self.pickerHasSecondaryTags) {
        for (UICollectionViewLayoutAttributes *attributes in attributeses) {
            if (attributes.indexPath.section == 0) {
                attributes.frame = CGRectOffset(attributes.frame, self.centeringOffset, 0);
            }
        }
    }
    return attributeses;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    if (self.pickerHasSecondaryTags) {
        return CGRectGetWidth(self.collectionView.bounds) != CGRectGetWidth(newBounds);
    } else {
        return [super shouldInvalidateLayoutForBoundsChange:newBounds];
    }
}

@end
