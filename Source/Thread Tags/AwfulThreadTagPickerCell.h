//  AwfulThreadTagPickerCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 * An AwfulThreadTagPickerCell represents a thread tag in an AwfulThreadTagPickerController.
 */
@interface AwfulThreadTagPickerCell : UICollectionViewCell

@property (strong, nonatomic) UIImage *image;

@end

/**
 * An AwfulSecondaryTagPickerCell represents a secondary thread tag (like Ask in Ask/Tell) in an AwfulThreadTagPickerController.
 */
@interface AwfulSecondaryTagPickerCell : UICollectionViewCell

/**
 * The image name of the secondary tag. The cell will draw its own rendition of the tag based on the image name.
 */
@property (strong, nonatomic) NSString *tagImageName;

/**
 * The color of the description that appears below the tag.
 */
@property (strong, nonatomic) UIColor *titleTextColor;

@end
