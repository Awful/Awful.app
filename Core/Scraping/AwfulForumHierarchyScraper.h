//  AwfulForumHierarchyScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class Forum;

NS_ASSUME_NONNULL_BEGIN

/// An AwfulForumHierarchyScraper builds up a hierarchy of Forum instances from a drop-down menu.
@interface AwfulForumHierarchyScraper : AwfulScraper

@property (readonly, nullable, copy, nonatomic) NSArray<Forum *> *forums;

@end

NS_ASSUME_NONNULL_END
