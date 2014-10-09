//  SmilieCell.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import <FLAnimatedImage/FLAnimatedImageView.h>

@interface SmilieCell : UICollectionViewCell

@property (readonly, strong, nonatomic) FLAnimatedImageView *imageView;

@property (strong, nonatomic) UIColor *normalBackgroundColor;
@property (strong, nonatomic) UIColor *selectedBackgroundColor;

@end
