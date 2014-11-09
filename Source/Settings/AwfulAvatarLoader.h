//  AwfulAvatarLoader.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@class User;

/**
 * An AwfulAvatarLoader fetches and caches avatar images.
 */
@interface AwfulAvatarLoader : NSObject

/**
 * Returns a shared instance configured with the default cache folder.
 */
+ (instancetype)loader;

/**
 * Designated initializer.
 */
- (id)initWithCacheFolder:(NSURL *)cacheFolder;

/**
 * Where to save images and cache information.
 */
@property (readonly, strong, nonatomic) NSURL *cacheFolder;

/**
 * If a cached avatar image exists for a user, it's applied to the given image view and YES is returned. Otherwise the image view is not modified, and NO is returned.
 *
 * (Why doesn't this method simply return a UIImage, you ask? So it can handle animated GIFs.)
 */
- (BOOL)applyCachedAvatarImageForUser:(User *)user toImageView:(UIImageView *)imageView;

/**
 * Finds and caches a user's current avatar image.
 *
 * @param completionBlock A block to call after finding an avatar image, which returns nothing and receives as parameters: YES if the avatar has changed from the cached image; a block to apply the avatar to a UIImageView; and an error if an error occurred.
 *
 * (Why doesn't the completion block simply receive a UIImage, you ask? So it can handle animated GIFs.)
 */
- (void)applyAvatarImageForUser:(User *)user
                completionBlock:(void (^)(BOOL modified, void (^applyBlock)(UIImageView *), NSError *error))completionBlock;

/**
 * Deletes all cached images and information.
 */
- (void)emptyCache;

@end
