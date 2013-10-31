//  ImgurHTTPClient.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
@protocol ImgurHTTPClientCancelToken;

/**
 * An ImgurHTTPClient uploads images using the Imgur Anonymous API, version 3.
 */
@interface ImgurHTTPClient : NSObject

/**
 * Convenient singleton instance.
 */
+ (instancetype)client;

// Upload images anonymously to Imgur, downscaling and rotating images as needed.
//
// images   - an array of UIImage instances to upload. Uploaded images may be downscaled.
// callback - a block that takes two arguments and returns nothing:
//              error - an NSError instance on failure, or nil if successful.
//              urls  - an array of NSURL instances pointing to the uploaded images if successful,
//                      or nil on failure.
//
// N.B. The callback is not called if the upload is cancelled.
//
// Returns an object that can cancel the upload if it receives -cancel. This object is retained
// until the upload operation succeeds or fails; holding a weak reference to it is OK (even
// recommended).

/**
 * Uploads images anonymously to Imgur, downscaling and rotating images as needed.
 *
 * @param images   An array of UIImage objects.
 * @param callback A block called after the upload that takes two parameters: an NSError object on failure or nil on success; and an array of NSURL objects on success or nil on failure. The callback is not called if the upload is cancelled.
 *
 * @return A token that can cancel the upload.
 */
- (id <ImgurHTTPClientCancelToken>)uploadImages:(NSArray *)images
                                        andThen:(void(^)(NSError *error, NSArray *urls))callback;

@end

@protocol ImgurHTTPClientCancelToken

- (void)cancel;

@end

extern NSString * const ImgurAPIErrorDomain;

enum {
    ImgurAPIErrorUnknown = -1,
    ImgurAPIErrorRateLimitExceeded = -1000,
    ImgurAPIErrorInvalidImage = -1001,
    ImgurAPIErrorActionNotSupported = -1002,
    ImgurAPIErrorUnexpectedRemoteError = -1003,
    ImgurAPIErrorMissingImageURL = -1004,
};
