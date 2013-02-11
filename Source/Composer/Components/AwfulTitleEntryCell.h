//
//  AwfulTitleEntryCell.h
//  Awful
//
//  Created by me on 2/4/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTextEntryCell.h"

@protocol AwfulTitleEntryCellDelegate <UITextFieldDelegate>
- (void)chooseThreadTag:(UIImageView*)imageView;

@end

@interface AwfulTitleEntryCell : AwfulTextEntryCell
@property (nonatomic) id<AwfulTitleEntryCellDelegate> delegate;
@end
