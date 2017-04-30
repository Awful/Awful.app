//  AwfulPostScraper.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class Post;

NS_ASSUME_NONNULL_BEGIN

/// An AwfulPostScraper scrapes a single AwfulPost object.
@interface AwfulPostScraper : AwfulScraper

@property (readonly, nullable, strong, nonatomic) Post *post;

@end

NS_ASSUME_NONNULL_END
