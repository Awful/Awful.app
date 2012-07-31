//
//  AwfulImageAttachmentCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulImageAttachmentCell.h"

@implementation AwfulImageAttachmentCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.text = @"Attachment:";
        self.detailTextLabel.text = @"None";
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

-(void) didSelectCell:(UIViewController *)viewController {
    //[viewController.navigationController pushViewController:[AwfulImageAttachmentChooser new] animated:YES];
}

@end
