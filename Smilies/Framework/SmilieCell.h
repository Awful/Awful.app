//  SmilieCell.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import <FLAnimatedImage/FLAnimatedImageView.h>

@interface SmilieCell : UICollectionViewCell

@property (readonly, strong, nonatomic) FLAnimatedImageView *imageView;

/**
 When editing, a SmilieCell will wiggle and display a remove control over its top left corner.
 */
@property (assign, nonatomic) BOOL editing;
@property (readonly, strong, nonatomic) UIImageView *removeControl;

@property (strong, nonatomic) UIColor *normalBackgroundColor;
@property (strong, nonatomic) UIColor *selectedBackgroundColor;

@end
