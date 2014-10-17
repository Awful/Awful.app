//  SmilieCollectionViewFlowLayout.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 Extends the flow layout to allow for drag-and-drop reordering, and adds an editing mode during which said reordering is possible.
 */
@interface SmilieCollectionViewFlowLayout : UICollectionViewFlowLayout

@property (assign, nonatomic) BOOL editing;

@property (assign, nonatomic) IBInspectable BOOL dragReorderingEnabled;

@end

@protocol SmilieCollectionViewFlowLayoutDataSource <UICollectionViewDataSource>

/**
 Sent when a cell's remove control is pressed. The cell is not automatically removed from the collection view; that's up to the data source.
 */
- (void)collectionView:(UICollectionView *)collectionView deleteItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 Sent during a drag, whenever the dragged cell has moved far enough to overtake other cells. The cells are automatically moved within the collection view; it's up to the data source to either keep track of the dragged cell's current location, or to update its underlying collection.
 */
- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)indexPath;

/**
 Sent once a drag has finished, possibly without any change in position. If the data source was avoiding changing its underlying collection, now is the time to make the change.
 */
- (void)collectionView:(UICollectionView *)collectionView didFinishDraggingItemToIndexPath:(NSIndexPath *)indexPath;

@end

@protocol SmilieCollectionViewDelegateFlowLayout <UICollectionViewDelegateFlowLayout>

/**
 Sent when a cell is long-pressed.
 */
- (void)collectionView:(UICollectionView *)collectionView didStartEditingItemAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface SmilieCollectionViewFlowLayoutAttributes : UICollectionViewLayoutAttributes

@property (assign, nonatomic) BOOL editing;

@end
