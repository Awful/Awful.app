//
//  ImgurHTTPClient.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-06.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AFNetworking.h"

// Client for the Imgur Anonymous API, version 2.
@interface ImgurHTTPClient : AFHTTPClient

// Singleton.
+ (ImgurHTTPClient *)sharedClient;

// images   - an array of UIImage instances to upload.
// callback - a block that takes two arguments and returns nothing:
//              error - an NSError instance on failure, or nil if successful.
//              urls  - an array of NSURL instances pointing to the uploaded images if successful,
//                      or nil on failure.
- (void)uploadImages:(NSArray *)images andThen:(void(^)(NSError *error, NSArray *urls))callback;

// Possible reasons for NO may include network reachability or API rate limiting.
- (void)checkIfAnyImagesCanBeUploadedAndThen:(void(^)(BOOL canUploadAtLeastOneImage))callback;

@end

extern NSString * const ImgurAPIErrorDomain;

enum {
    ImgurAPIErrorUnknown = -1,
    ImgurAPIErrorRateLimitExceeded = -1000,
    ImgurAPIErrorInvalidImage = -1001,
};
