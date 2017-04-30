//  PrivateMessageScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class PrivateMessage;

NS_ASSUME_NONNULL_BEGIN

/// A PrivateMessageScraper scrapes a standalone AwfulPrivateMessage.
@interface PrivateMessageScraper : AwfulScraper

@property (readonly, nullable, strong, nonatomic) PrivateMessage *privateMessage;

@end

NS_ASSUME_NONNULL_END
