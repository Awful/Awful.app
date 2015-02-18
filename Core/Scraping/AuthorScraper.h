//  AuthorScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <AwfulCore/AwfulScraper.h>
@class User;

/// An AuthorScraper scrapes an User from information near a post or profile.
@interface AuthorScraper : AwfulScraper

@property (readonly, copy, nonatomic) NSString *userID;

@property (readonly, copy, nonatomic) NSString *username;

@property (readonly, copy, nonatomic) NSDictionary *otherAttributes;

/// Gets a lazily-fetched or -created User for the scraped userID and/or username.
@property (strong, nonatomic) User *author;

@end
