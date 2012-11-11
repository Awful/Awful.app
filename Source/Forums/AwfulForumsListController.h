//
//  AwfulForumsListController.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFetchedTableViewController.h"
@class AwfulForum;

@interface AwfulForumsListController : AwfulFetchedTableViewController

- (void)showForum:(AwfulForum *)forum;

@end
