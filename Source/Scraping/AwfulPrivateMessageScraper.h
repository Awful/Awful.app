//  AwfulPrivateMessageScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

/**
 * An AwfulPrivateMessageScraper scrapes a standalone AwfulPrivateMessage.
 */
@interface AwfulPrivateMessageScraper : AwfulScraper

@property (readonly, strong, nonatomic) AwfulPrivateMessage *privateMessage;

@end
