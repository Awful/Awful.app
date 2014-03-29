//  AwfulAuthorScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

/**
 * An AwfulAuthorScraper scrapes an AwfulUser from information near a post or profile.
 */
@interface AwfulAuthorScraper : AwfulScraper

@property (readonly, strong, nonatomic) AwfulUser *author;

@end
