//  AwfulUnreadPrivateMessageCountScraper.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulUnreadPrivateMessageCountScraper.h"
#import "HTMLNode+CachedSelector.h"

@interface AwfulUnreadPrivateMessageCountScraper ()

@property (assign, nonatomic) NSInteger unreadPrivateMessageCount;

@end

@implementation AwfulUnreadPrivateMessageCountScraper

- (void)scrape
{
    self.unreadPrivateMessageCount = [self.node awful_nodesMatchingCachedSelector:@"table.standard img[src*='newpm']"].count;
}

@end
