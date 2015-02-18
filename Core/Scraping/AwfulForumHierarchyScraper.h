//  AwfulForumHierarchyScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <AwfulCore/AwfulScraper.h>

/// An AwfulForumHierarchyScraper builds up a hierarchy of Forum instances from a drop-down menu.
@interface AwfulForumHierarchyScraper : AwfulScraper

@property (readonly, copy, nonatomic) NSArray *forums;

@end
