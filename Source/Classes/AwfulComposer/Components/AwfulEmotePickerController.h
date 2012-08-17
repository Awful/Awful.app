//
//  AwfulEmoteChooser.h
//  Awful
//
//  Created by me on 5/6/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulGridViewController.h"
static NSString* const AwfulEmoteChosenNotification = @"com.regularberry.awful.notifications.emoteChosen";

@interface AwfulEmotePickerController : AwfulGridViewController <UISearchBarDelegate> {
    NSMutableArray* imagesToCache;
}

@property (nonatomic, strong) IBOutlet UISearchBar* searchBar;


@end
