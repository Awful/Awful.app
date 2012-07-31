//
//  AwfulThreadTagPickerController.h
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulGridViewController.h"

static NSString* const AwfulThreadTagPickedNotification = @"com.regularberry.awful.notifications.threadtag";

@interface AwfulThreadTagPickerController : AwfulGridViewController

-(id) initWithForum:(AwfulForum*)forum;
@end
