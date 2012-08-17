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
        self.detailTextLabel.text = @" ";
    }
    return self;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.textField.frame = self.detailTextLabel.frame;
    self.textField.fsW = 200;
    
}

-(void) didSelectCell:(UIViewController *)viewController {
    [self.accessoryView becomeFirstResponder];
}

-(void) textFieldDidEndEditing:(UITextField *)textField {
    [self.draft setValue:textField.text forKey:[self.dictionary objectForKey:AwfulPostCellDraftInputKey]];
}

-(UITextField*) textField {
    if (!_textField) {
        _textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 250, 30)];
        _textField.delegate = self;
        _textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_textField];
    }
    return _textField;
}

@end
