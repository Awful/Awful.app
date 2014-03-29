//  AwfulProfileScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

/**
 * An AwfulProfileScraper scrapes an AwfulUser object from a profile page.
 */
@interface AwfulProfileScraper : AwfulScraper

@property (readonly, strong, nonatomic) AwfulUser *user;

@end
