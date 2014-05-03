//  AwfulForum.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForum.h"

@implementation AwfulForum

@dynamic canPost;
@dynamic forumID;
@dynamic index;
@dynamic lastRefresh;
@dynamic lastFilteredRefresh;
@dynamic name;
@dynamic category;
@dynamic children;
@dynamic parentForum;
@dynamic threads;
@dynamic threadTags;
@dynamic secondaryThreadTags;

+ (instancetype)fetchOrInsertForumInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                                                  withID:(NSString *)forumID
{
    AwfulForum *forum = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                           matchingPredicateFormat:@"forumID = %@", forumID];
    if (!forum) {
        forum = [AwfulForum insertInManagedObjectContext:managedObjectContext];
        forum.forumID = forumID;
    }
    return forum;
}

@end
