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
 * Returns a cached avatar image for a user, or nil if no cached image is found.
 */
- (UIImage *)cachedAvatarImageForUser:(AwfulUser *)user;

/**
 * Finds and caches a user's current avatar image.
 *
 * @param completionBlock A block to call after finding an avatar image, which returns nothing and takes three parameter: the user's avatar image if downloaded, or nil otherwise; YES if a new avatar was downloaded, or NO otherwise; and nil on success, or an error on failure.
 */
- (void)avatarImageForUser:(AwfulUser *)user completion:(void (^)(UIImage *avatarImage, BOOL modified, NSError *error))completionBlock;

/**
 * Deletes all cached images and information.
 */
- (void)emptyCache;

@end
