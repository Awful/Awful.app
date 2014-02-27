//  AwfulActionView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulActionView is the content view of an AwfulActionViewController.
 */
@interface AwfulActionView : UIView

/**
 * A title shown above the grid of icons.
 */
@property (readonly, strong, nonatomic) UILabel *titleLabel;

/**
 * The collectionView's delegate and dataSource need to be set, and cell classes must be registered. Layout is manged by the AwfulActionView.
 */
@property (readonly, strong, nonatomic) UICollectionView *collectionView;

@end
