//
//  AwfulForumsListControllerSubclass.h
//  Awful
//
//  Created by Nolan Waite on 12-04-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsListController.h"
#import "AwfulForumSection.h"

@class AwfulForum;

@interface AwfulForumsListController ()

@property (nonatomic, strong) NSMutableArray *forumSections;

@property (nonatomic, readonly) NSPredicate *forumsPredicate;

- (void)loadForums;
- (void)toggleExpandForForumSection:(AwfulForumSection *)section;

- (AwfulForum *)getForumAtIndexPath:(NSIndexPath *)path;
- (AwfulForumSection *)getForumSectionAtIndexPath:(NSIndexPath *)path;

@end

