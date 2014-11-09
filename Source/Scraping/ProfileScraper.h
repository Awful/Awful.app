//  ProfileScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class User;

/**
 * An ProfileScraper scrapes a User object from a profile page.
 */
@interface ProfileScraper : AwfulScraper

@property (readonly, strong, nonatomic) User *user;

@end
