//  AwfulIconActionCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulIconActionCell shows an image horizontally centred with a horizontally-centred two-line title below.
 */
@interface AwfulIconActionCell : UICollectionViewCell

/**
 * Icons in highlighted cells are always tinted white.
 */
@property (readonly, strong, nonatomic) UIImageView *iconImageView;

@property (readonly, strong, nonatomic) UILabel *titleLabel;

/**
 * The tintColor affects just the iconImageView, and even then only so long as the cell is not highlighted.
 */
@property (strong, nonatomic) UIColor *tintColor;

@end
