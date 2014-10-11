//  SmilieCollectionViewFlowLayout.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface SmilieCollectionViewFlowLayout : UICollectionViewFlowLayout

@property (assign, nonatomic) IBInspectable BOOL dragReorderingEnabled;

@end

@protocol SmilieCollectionViewFlowLayoutDataSource <UICollectionViewDataSource>

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)indexPath;

- (void)collectionView:(UICollectionView *)collectionView didFinishDraggingItemToIndexPath:(NSIndexPath *)indexPath;

@end
