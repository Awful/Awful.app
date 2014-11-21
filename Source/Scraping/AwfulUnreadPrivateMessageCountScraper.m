//  AwfulUnreadPrivateMessageCountScraper.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulUnreadPrivateMessageCountScraper.h"

@interface AwfulUnreadPrivateMessageCountScraper ()

@property (assign, nonatomic) NSInteger unreadPrivateMessageCount;

@end

@implementation AwfulUnreadPrivateMessageCountScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    self.unreadPrivateMessageCount = [self.node nodesMatchingSelector:@"table.standard img[src*='newpm']"].count;
}

@end
