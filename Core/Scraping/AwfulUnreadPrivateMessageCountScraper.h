//  AwfulUnreadPrivateMessageCountScraper.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

NS_ASSUME_NONNULL_BEGIN

/// An AwfulUnreadPrivateMessageCountScraper scrapes the private message inbox for the number of unread messages.
@interface AwfulUnreadPrivateMessageCountScraper : AwfulScraper

@property (readonly, assign, nonatomic) NSInteger unreadPrivateMessageCount;

@end

NS_ASSUME_NONNULL_END
