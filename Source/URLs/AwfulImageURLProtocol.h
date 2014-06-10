//  AwfulImageURLProtocol.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

/**
 * An AwfulImageURLProtocol implements the awful-image protocol, serving UIImage objects at arbitrary URLs.
 */
@interface AwfulImageURLProtocol : NSURLProtocol

/**
 * Adds an image whose data is served at the given path. The image's data will be held in memory; consider passing a thumbnail image where appropriate. If another image was being served at the path, it is replaced.
 *
 * @return An NSURL suitable for use in a UIWebView, for passing to an API based on the Foundation URL Loading System, and for passing to +stopHostingImageAtURL:.
 */
+ (NSURL *)serveImage:(UIImage *)image atPath:(NSString *)path;

/**
 * Adds an image from the asset library whose data is served at the given path. The image's data will be held in memory. If another image was being served at the path, it is replaced.
 *
 * @param assetURL A URL representing an ALAsset.
 *
 * @return An NSURL suitable for use in a UIWebView, for passing to an API based on the Foundation URL Loading System, and for passing to +stopHostingImageAtURL:.
 */
+ (NSURL *)serveAsset:(NSURL *)assetURL atPath:(NSString *)path;

/**
 * Stops hosting a previously-hosted image and release the image's memory.
 */
+ (void)stopServingImageAtURL:(NSURL *)URL;

@end

/**
 * Equal to "awful-image".
 */
extern NSString * const AwfulImageURLScheme;
