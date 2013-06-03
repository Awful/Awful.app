//
//  AwfulIconActionCell.h
//  Awful
//
//  Created by Nolan Waite on 2013-04-25.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <PSTCollectionView/PSTCollectionView.h>

@interface AwfulIconActionCell : PSUICollectionViewCell

@property (copy, nonatomic) NSString *title;
@property (nonatomic) UIImage *icon;
@property (nonatomic) UIColor *tintColor;

@end
