//  PrivateMessageScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <AwfulCore/AwfulScraper.h>
@class PrivateMessage;

/// A PrivateMessageScraper scrapes a standalone AwfulPrivateMessage.
@interface PrivateMessageScraper : AwfulScraper

@property (readonly, strong, nonatomic) PrivateMessage *privateMessage;

@end
