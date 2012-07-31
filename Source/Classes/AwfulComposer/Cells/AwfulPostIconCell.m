//
//  AwfulPostIconCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostIconCell.h"
#import "AwfulThreadTagPickerController.h"
#import "AwfulEmote.h"

@implementation AwfulPostIconCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.text = @"Thread Tag:";
        self.detailTextLabel.text = @"None";
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didPickThreadTag:)
                                                     name:AwfulThreadTagPickedNotification
                                                   object:nil
         ];
    }
    return self;
}

-(void) didSelectCell:(UIViewController *)viewController {
    [viewController.navigationController pushViewController:[[AwfulThreadTagPickerController alloc] initWithForum:nil] animated:YES];
}

-(void) didPickThreadTag:(NSNotification*)notificatiion {
    AwfulEmote* emote = [notificatiion.userInfo objectForKey:@"tag"];
    self.detailTextLabel.text = nil;
    self.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:emote.filename.lastPathComponent]];
}

@end
