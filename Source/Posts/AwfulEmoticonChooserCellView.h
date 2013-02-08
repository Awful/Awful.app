//
//  AwfulEmoticonChooserCellView.h
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PSTCollectionViewCell.h"
#import "AwfulEmoticon.h"

@interface AwfulEmoticonChooserCellView : PSTCollectionViewCell
@property (nonatomic,strong,readonly) UILabel* textLabel;
@property (nonatomic,strong,readonly) UIImageView* imageView;
@property (nonatomic) AwfulEmoticon* emoticon;
@end
