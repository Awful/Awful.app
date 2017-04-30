//  AuthorScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class User;

NS_ASSUME_NONNULL_BEGIN

/// An AuthorScraper scrapes an User from information near a post or profile.
@interface AuthorScraper : AwfulScraper

@property (readonly, nullable, copy, nonatomic) NSString *userID;

@property (readonly, nullable, copy, nonatomic) NSString *username;

@property (readonly, nullable, copy, nonatomic) NSDictionary *otherAttributes;

/// Gets a lazily-fetched or -created User for the scraped userID and/or username.
@property (nullable, strong, nonatomic) User *author;

@end

NS_ASSUME_NONNULL_END
