//  AwfulPrivateMessageFolderScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

/**
 * An AwfulPrivateMessageFolderScraper scrapes a list of AwfulPrivateMessage objects from a folder list.
 */
@interface AwfulPrivateMessageFolderScraper : AwfulScraper

@property (readonly, copy, nonatomic) NSArray *messages;

@end
