//  ProfileScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class Profile;

NS_ASSUME_NONNULL_BEGIN

/// A ProfileScraper scrapes a User object from a profile page.
@interface ProfileScraper : AwfulScraper

@property (readonly, nullable, strong, nonatomic) Profile *profile;

@end

NS_ASSUME_NONNULL_END
