//
//  AwfulTextFieldCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTextFieldCell.h"
#import "AwfulDraft.h"

@implementation AwfulTextFieldCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.text = @"Subject:";
        UITextField* tf = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 250, 30)];
        tf.delegate = self;
        self.contentMode = UIViewContentModeCenter;
        self.accessoryView = tf;
    }
    return self;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.accessoryView.fsH = self.contentView.fsH;
}

-(void) didSelectCell:(UIViewController *)viewController {
    [self.accessoryView becomeFirstResponder];
}

-(void) textFieldDidEndEditing:(UITextField *)textField {
    [self.draft setValue:textField.text forKey:[self.dictionary objectForKey:AwfulPostCellDraftInputKey]];
}

@end
