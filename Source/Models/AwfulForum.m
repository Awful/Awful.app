//  AwfulForum.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForum.h"
#import "AwfulSettings.h"

@implementation AwfulForum

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

- (NSString *)abbreviatedName
{
    static NSDictionary *abbreviations;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *abbreviationsURL = [[NSBundle mainBundle] URLForResource:@"Forum Abbreviations" withExtension:@"plist"];
        abbreviations = [NSDictionary dictionaryWithContentsOfURL:abbreviationsURL];
    });
    if (!self.forumID) return nil;
    return abbreviations[self.forumID] ?: self.name;
}

- (BOOL)childrenExpanded
{
	return [[AwfulSettings settings] childrenExpandedForForumWithID:self.forumID];
}

- (void)setChildrenExpanded:(BOOL)childrenExpanded
{
	[[AwfulSettings settings] setChildrenExpanded:childrenExpanded forForumWithID:self.forumID];
}

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
