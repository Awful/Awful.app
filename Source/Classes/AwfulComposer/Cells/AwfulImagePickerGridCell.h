//
//  AwfulImagePickerGridCell.h
//  Awful
//
//  Created by me on 7/31/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FVGifAnimation;

@interface AwfulImagePickerGridCell : UITableViewCell
@property (nonatomic,readwrite) BOOL showLabel;
@property (nonatomic,readwrite) NSString* imagePath;
@property (nonatomic,strong) FVGifAnimation* animation;
@end
