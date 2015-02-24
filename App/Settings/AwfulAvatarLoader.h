//  AwfulAvatarLoader.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import <FLAnimatedImage/FLAnimatedImage.h>
@class User;

/**
 * An AwfulAvatarLoader fetches and caches avatar images.
 */
@interface AwfulAvatarLoader : NSObject

/**
 * Returns a shared instance configured with the default cache folder.
 */
+ (instancetype)loader;

- (instancetype)initWithCacheFolder:(NSURL *)cacheFolder NS_DESIGNATED_INITIALIZER;

/**
 * Where to save images and cache information.
 */
@property (readonly, strong, nonatomic) NSURL *cacheFolder;

/**
 * Returns a cached avatar image, if one exists for the user. Otherwise returns nil.
 */
- (id /* UIImage or FLAnimatedImage */)cachedAvatarImageForUser:(User *)user;

/**
 * Finds and caches a user's current avatar image.
 *
 * @param completionBlock A block to call after finding an avatar image, which returns nothing and receives as parameters: YES if the avatar has changed from the cached image; the image if it is successfully found and has been modified; and an error if an error occurred.
 */
- (void)fetchAvatarImageForUser:(User *)user
                completionBlock:(void (^)(BOOL modified, id /* UIImage or FLAnimatedImage */ image, NSError *error))completionBlock;

/**
 * Deletes all cached images and information.
 */
- (void)emptyCache;

@end
