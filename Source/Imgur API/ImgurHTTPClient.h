//
//  ImgurHTTPClient.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import <AFNetworking/AFNetworking.h>
@protocol ImgurHTTPClientCancelToken;

// Client for the Imgur Anonymous API, version 3.
@interface ImgurHTTPClient : AFHTTPClient

// Singleton.
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
