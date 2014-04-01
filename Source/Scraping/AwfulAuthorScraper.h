//  AwfulAuthorScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

/**
 * An AwfulAuthorScraper scrapes an AwfulUser from information near a post or profile.
 */
@interface AwfulAuthorScraper : AwfulScraper

@property (readonly, copy, nonatomic) NSString *userID;

@property (readonly, copy, nonatomic) NSString *username;

@property (readonly, copy, nonatomic) NSDictionary *otherAttributes;

/**
 * Gets a lazily-fetched or -created AwfulUser for the scraped userID and/or username. Sets
 */
@property (strong, nonatomic) AwfulUser *author;

@end
