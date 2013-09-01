//  AwfulIconActionCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <PSTCollectionView/PSTCollectionView.h>

@interface AwfulIconActionCell : PSUICollectionViewCell

@property (copy, nonatomic) NSString *title;
@property (nonatomic) UIImage *icon;
@property (nonatomic) UIColor *tintColor;

@end
