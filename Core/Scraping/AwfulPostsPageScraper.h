//  AwfulPostsPageScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <AwfulCore/AwfulScraper.h>
@class Thread;

/// An AwfulPostsPageScraper scrapes a list of AwfulPost objects from a page of a thread.
@interface AwfulPostsPageScraper : AwfulScraper

@property (readonly, strong, nonatomic) Thread *thread;

@property (readonly, copy, nonatomic) NSArray *posts;

@property (readonly, copy, nonatomic) NSString *advertisementHTML;

@end
