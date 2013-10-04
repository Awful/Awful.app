//  AwfulPost.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "_AwfulPost.h"
@class PageParsedInfo;

@interface AwfulPost : _AwfulPost

@property (readonly, nonatomic) BOOL beenSeen;

// Returns 0 if the page is unknown.
@property (readonly, nonatomic) NSInteger page;

// Returns 0 if the page is unknown.
@property (readonly, nonatomic) NSInteger singleUserPage;

+ (NSArray *)postsCreatedOrUpdatedFromPageInfo:(PageParsedInfo *)pageInfo
                        inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

+ (instancetype)firstOrNewPostWithPostID:(NSString *)postID
                  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
