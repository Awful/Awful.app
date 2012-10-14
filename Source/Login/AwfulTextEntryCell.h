//
//  AwfulTextEntryCell.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-14.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulTextEntryCell : UITableViewCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property (readonly, weak, nonatomic) UITextField *textField;

@end
