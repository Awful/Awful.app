//  AwfulThreadListScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

/**
 * An AwfulThreadListScraper scrapes a list of AwfulThread objects from a forum or a page of bookmarks.
 */
@interface AwfulThreadListScraper : AwfulScraper

@property (readonly, strong, nonatomic) AwfulForum *forum;

@property (readonly, copy, nonatomic) NSArray *threads;

@end
