//
//  AwfulPostIconCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostIconCell.h"
#import "AwfulThreadTagPickerController.h"
#import "AwfulThreadTag.h"

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
    AwfulThreadTag* tag = notificatiion.object;
    self.detailTextLabel.text = nil;
    self.imageView.image = tag.image;
    
    if (!tag.image)
        self.detailTextLabel.text = tag.alt;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    
    if (self.imageView.image) {
        self.textLabel.foX = self.imageView.foX;
        self.imageView.foX = self.contentView.fsW - self.imageView.fsW - 30;
    }
}

@end
