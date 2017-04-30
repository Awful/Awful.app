//  AwfulPostsPageScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class Post;
@class Thread;

NS_ASSUME_NONNULL_BEGIN

/// An AwfulPostsPageScraper scrapes a list of AwfulPost objects from a page of a thread.
@interface AwfulPostsPageScraper : AwfulScraper

@property (readonly, nullable, strong, nonatomic) Thread *thread;

@property (readonly, nullable, copy, nonatomic) NSArray<Post *> *posts;

@property (readonly, nullable, copy, nonatomic) NSString *advertisementHTML;

@end

NS_ASSUME_NONNULL_END
