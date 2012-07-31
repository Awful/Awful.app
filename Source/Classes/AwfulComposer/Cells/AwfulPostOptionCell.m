//
//  AwfulPostOptionsCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostOptionCell.h"

@implementation AwfulPostOptionCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.text = @"Option";
        UISwitch *optionSwitch = [UISwitch new];
        [optionSwitch addTarget:self action:@selector(didToggleSwitch:) forControlEvents:UIControlEventValueChanged];
        self.accessoryView = optionSwitch;
    }
    return self;
}

-(void) didToggleSwitch:(UISwitch*)optionSwitch {
    [self.draft setValue:[NSNumber numberWithBool:optionSwitch.isOn]
                  forKey:[self.dictionary objectForKey:AwfulPostCellDraftInputKey]
     ];
    
}
@end
