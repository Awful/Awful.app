//
//  AwfulEmoteChooser.h
//  Awful
//
//  Created by me on 5/6/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFetchedTableViewController.h"
static NSString* const AwfulEmoteChosenNotification = @"com.regularberry.awful.notifications.emoteChosen";

@interface AwfulEmoteChooser : AwfulFetchedTableViewController <UISearchBarDelegate> {
    int _numIconsPerRow;
    NSMutableArray* imagesToCache;
}

@property (nonatomic, strong) IBOutlet UISearchBar* searchBar;


@end
