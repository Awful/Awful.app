//  PrivateMessageFolderScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <AwfulCore/AwfulScraper.h>

/// A PrivateMessageFolderScraper scrapes a list of PrivateMessage objects from a folder list.
@interface PrivateMessageFolderScraper : AwfulScraper

@property (readonly, copy, nonatomic) NSArray *messages;

@end
