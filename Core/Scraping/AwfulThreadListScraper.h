//  AwfulThreadListScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class Forum;
@class Thread;

NS_ASSUME_NONNULL_BEGIN

/// An AwfulThreadListScraper scrapes a list of AwfulThread objects from a forum or a page of bookmarks.
@interface AwfulThreadListScraper : AwfulScraper

@property (readonly, nullable, strong, nonatomic) Forum *forum;

@property (readonly, nullable, copy, nonatomic) NSArray/*<Thread *>*/ *threads;

@end

NS_ASSUME_NONNULL_END
