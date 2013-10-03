//  AwfulForum.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "_AwfulForum.h"
#import "AwfulParsing.h"

@interface AwfulForum : _AwfulForum {}

+ (instancetype)fetchOrInsertForumInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                                                  withID:(NSString *)forumID;

+ (NSArray *)updateCategoriesAndForums:(ForumHierarchyParsedInfo *)info
                inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
