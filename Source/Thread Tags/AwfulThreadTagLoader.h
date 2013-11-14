//  AwfulThreadTagLoader.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulThreadTagLoader can retrieve thread tag images in the app and from Awful's GitHub repository.
 */
@interface AwfulThreadTagLoader : NSObject

/**
 * Convenient singleton instance.
 */
+ (AwfulThreadTagLoader *)loader;

/**
 * Loads and caches an Awful-style thread tag, searching Awful's GitHub repository if necessary.
 *
 * @param threadTagName The basename of the thread tag (i.e. without a path or extension). If the thread tag is located at http://fi.somethingawful.com/forums/posticons/lan-canada.gif#576 you should pass `lan-canada` for this parameter.
 *
 * @return nil if no image is available. Listen for AwfulNewThreadTagsAvailableNotification to find out about newly-downloaded tag images.
 */
- (UIImage *)imageNamed:(NSString *)imageName;

/**
 * Returns a generic image suitable for a thread without a tag.
 */
- (UIImage *)emptyThreadTagImage;

/**
 * Returns a generic image suitable for a message without a tag.
 */
- (UIImage *)emptyPrivateMessageImage;

@end

/**
 * Posted when a thread tag image becomes newly available or updates. The notification's object is the AwfulThreadTagLoader that downloaded the image. The notification's userInfo contains a value for the AwfulThreadTagLoaderNewImageNameKey.
 */
extern NSString * const AwfulThreadTagLoaderNewImageAvailableNotification;

/**
 * Value is an NSString suitable for -[AwfulThreadTagLoader threadTagNamed:].
 */
extern NSString * const AwfulThreadTagLoaderNewImageNameKey;
