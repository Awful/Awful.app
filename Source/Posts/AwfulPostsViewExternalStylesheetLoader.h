//  AwfulPostsViewExternalStylesheetLoader.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

/**
 * An AwfulPostsViewExternalStylesheetLoader continually downloads a stylesheet meant to be inserted into a posts view. This allows for design changes without going through app review.
 */
@interface AwfulPostsViewExternalStylesheetLoader : NSObject

/**
 * Returns a shared instance configured with the default cache folder and the stylesheet URL loaded from Info.plist.
 */
+ (instancetype)loader;

/**
 * Designated initializer.
 */
- (instancetype)initWithStylesheetURL:(NSURL *)stylesheetURL cacheFolder:(NSURL *)cacheFolder;

/**
 * Wherefrom the external stylesheet is retrieved.
 */
@property (readonly, strong, nonatomic) NSURL *stylesheetURL;

/**
 * Where to save the stylesheet and cache information.
 */
@property (readonly, strong, nonatomic) NSURL *cacheFolder;

/**
 * The most recently downloaded version of the external stylesheet.
 */
@property (readonly, copy, nonatomic) NSString *stylesheet;

/**
 * Check for a new external stylesheet, if it's been awhile since the loader last checked.
 *
 * @note An AwfulPostsViewExternalStylesheetLoader will peroidically check for a new external stylesheet on its own, so there is no *need* to call this method.
 */
- (void)refreshIfNecessary;

/**
 * Deletes the cached stylesheet and information.
 */
- (void)emptyCache;

@end

/**
 * Equal to "AwfulPostsViewExternalStylesheetURL".
 */
extern NSString * const AwfulPostsViewExternalStylesheetLoaderStylesheetURLKey;

/**
 * Sent to the default notification center when a new stylesheet is downloaded. The notification's object is an NSString of the stylesheet.
 */
extern NSString * const AwfulPostsViewExternalStylesheetLoaderDidUpdateNotification;
