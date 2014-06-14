//  AwfulThreadTagLoader.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 * An AwfulThreadTagLoader loads thread tag images, both from those shipped with the app and those updated at the GitHub repository.
 */
@interface AwfulThreadTagLoader : NSObject

/**
 * Loads and caches a thread tag image using the convenient singleton.
 *
 * @param imageName The basename of the thread tag (i.e. no path or extension).
 *
 * @return The requested image, or nil if no image is available.
 *
 * @note Failed requests (i.e. when nil is returned) may trigger a check for new thread tags. Observe AwfulNewThreadTagsAvailableNotification to learn of newly-downloaded tag images.
 */
+ (UIImage *)imageNamed:(NSString *)imageName;

/**
 * A generic image representing a thread.
 */
+ (UIImage *)emptyThreadTagImage;

/**
 * A generic image representing a private message.
 */
+ (UIImage *)emptyPrivateMessageImage;

/**
 * A placeholder image representing "no selection".
 */
+ (UIImage *)unsetThreadTagImage;

/**
 * A placeholder image representing "no filter".
 */
+ (UIImage *)noFilterTagImage;

/**
 * Convenient singleton.
 */
+ (instancetype)loader;

/**
 * Designated initializer.
 */
- (instancetype)initWithTagListURL:(NSURL *)tagListURL cacheFolder:(NSURL *)cacheFolder;

/**
 * The location of a list of tags available for download.
 */
@property (readonly, strong, nonatomic) NSURL *tagListURL;

/**
 * Where to save updated thread tags.
 */
@property (readonly, strong, nonatomic) NSURL *cacheFolder;

/**
 * Loads and caches a thread tag image.
 *
 * @param imageName The basename of the thread tag (i.e. no path or extension).
 *
 * @return The requested image, or nil if no image is available.
 *
 * @note Failed requests (i.e. when nil is returned) may trigger a check for new thread tags. Observe AwfulNewThreadTagsAvailableNotification to learn of newly-downloaded tag images.
 */
- (UIImage *)imageNamed:(NSString *)imageName;

/**
 * Checks for new thread tags.
 */
- (void)updateIfNecessary;

@end

/**
 * Posted when a thread tag image becomes newly available or updates. The notification's object is the AwfulThreadTagLoader that downloaded the image. The notification's userInfo contains a value for the AwfulThreadTagLoaderNewImageNameKey.
 */
extern NSString * const AwfulThreadTagLoaderNewImageAvailableNotification;

/**
 * Value is an NSString suitable for -[AwfulThreadTagLoader threadTagNamed:].
 */
extern NSString * const AwfulThreadTagLoaderNewImageNameKey;
