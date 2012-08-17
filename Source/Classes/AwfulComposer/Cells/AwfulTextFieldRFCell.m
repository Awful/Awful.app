//
//  AwfulTextFieldRFCell.m
//  Awful
//
//  Created by me on 8/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTextFieldRFCell.h"

@implementation AwfulTextFieldRFCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.text = @"Subject:";
        
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:
                                   [NSArray arrayWithObjects:@"Reply", @"Forward", nil]
                                   ];
        seg.segmentedControlStyle = UISegmentedControlStyleBar;
        seg.selectedSegmentIndex = 0;
        [seg addTarget:self action:@selector(segmentedControlChanged:) forControlEvents:UIControlEventValueChanged];
        self.accessoryView = seg;
        
    }
    return self;
}

-(void) segmentedControlChanged:(UISegmentedControl*)segmentedControl {
    if (segmentedControl.selectedSegmentIndex == 0)  { //reply
        self.textField.text = [self.dictionary objectForKey:AwfulPostCellDetailKey];
        self.textField.userInteractionEnabled = NO;
    }
    else { //forward
        self.textField.text = nil;
        self.textField.userInteractionEnabled = YES;
        [self.textField becomeFirstResponder];
    }
}

-(void) setDictionary:(NSDictionary *)dictionary {
    [super setDictionary:dictionary];
    self.textField.text = [dictionary objectForKey:AwfulPostCellDetailKey];
    self.detailTextLabel.hidden = YES;
}

@end
