//  PrivateMessageFolderScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class PrivateMessage;

NS_ASSUME_NONNULL_BEGIN

/// A PrivateMessageFolderScraper scrapes a list of PrivateMessage objects from a folder list.
@interface PrivateMessageFolderScraper : AwfulScraper

@property (readonly, nullable, copy, nonatomic) NSArray<PrivateMessage *> *messages;

@end

NS_ASSUME_NONNULL_END
