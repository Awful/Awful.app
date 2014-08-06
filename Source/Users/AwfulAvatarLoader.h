//  AwfulAvatarLoader.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

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
 * (Why doesn't this method simply return a UIImage? So it can handle animated GIFs.)
 */
- (BOOL)applyCachedAvatarImageForUser:(AwfulUser *)user toImageView:(UIImageView *)imageView;

/**
 * Finds and caches a user's current avatar image.
 *
 * @param completionBlock A block to call after finding an avatar image, which returns the image view to fill with the avatar and takes two parameters: YES if a new avatar was downloaded, or NO if the avatar had not changed; and nil on success, or an error on failure.
 *
 * (Why does't the completion block simply receive a UIImage? So it can handle animated GIFs.)
 */
- (void)applyAvatarImageForUser:(AwfulUser *)user toImageViewAfterCompletion:(UIImageView *(^)(BOOL modified, NSError *error))completionBlock;

/**
 * Deletes all cached images and information.
 */
- (void)emptyCache;

@end
