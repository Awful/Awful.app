//
//  ImgurHTTPClient.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-06.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ImgurHTTPClient.h"
#import "NSData+Base64.h"
#import "UIImage+Resize.h"

@interface ImageResizeOperation : NSOperation

- (id)initWithImages:(NSArray *)images;

@property (copy, nonatomic) NSArray *images;

@property (copy, nonatomic) NSArray *base64EncodedImageStrings;

@end


@implementation ImgurHTTPClient

+ (ImgurHTTPClient *)client
{
    static ImgurHTTPClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.imgur.com/"]];
    });
    return instance;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if (!(self = [super initWithBaseURL:url])) return nil;
    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [self setDefaultHeader:@"Authorization" value:@"Client-ID 4db466addcb5cfc"];
    return self;
}

// TODO make cancelable
- (void)uploadImages:(NSArray *)images andThen:(void(^)(NSError *error, NSArray *urls))callback
{
    ImageResizeOperation *resizeOp = [[ImageResizeOperation alloc] initWithImages:images];
    resizeOp.completionBlock = ^{
        [self uploadBase64EncodedImageStrings:resizeOp.base64EncodedImageStrings
                                      andThen:callback];
    };
    [self.operationQueue addOperation:resizeOp];
}

- (void)uploadBase64EncodedImageStrings:(NSArray *)base64EncodedImageStrings
                                andThen:(void (^)(NSError *error, NSArray *urls))callback
{
    NSMutableArray *requests = [NSMutableArray new];
    for (NSString *base64String in base64EncodedImageStrings) {
        NSDictionary *dict = @{ @"image": base64String };
        [requests addObject:[self requestWithMethod:@"POST" path:@"/3/image.json" parameters:dict]];
    }
    [self enqueueBatchOfHTTPRequestOperationsWithRequests:requests
                                            progressBlock:nil
                                          completionBlock:^(NSArray *listOfOperations)
     {
         NSMutableArray *listOfURLs = [NSMutableArray new];
         for (AFJSONRequestOperation *operation in listOfOperations) {
             NSDictionary *response = operation.responseJSON;
             if (!operation.hasAcceptableStatusCode) {
                 if (callback) {
                     NSInteger errorCode = ImgurAPIErrorUnknown;
                     if (operation.response.statusCode == 400) {
                         errorCode = ImgurAPIErrorInvalidImage;
                     } else if (operation.response.statusCode == 403) {
                         errorCode = ImgurAPIErrorRateLimitExceeded;
                     } else if (operation.response.statusCode == 404) {
                         errorCode = ImgurAPIErrorActionNotSupported;
                     } else if (operation.response.statusCode == 500) {
                         errorCode = ImgurAPIErrorUnexpectedRemoteError;
                     }
                     NSString *message = response[@"data"][@"error"][@"message"];
                     if (!message) message = @"An unknown error occurred";
                     NSDictionary *userInfo = @{
                         NSLocalizedDescriptionKey : message,
                         NSUnderlyingErrorKey : operation.error
                     };
                     NSError *error = [NSError errorWithDomain:ImgurAPIErrorDomain
                                                          code:errorCode
                                                      userInfo:userInfo];
                     dispatch_async(dispatch_get_main_queue(), ^{ callback(error, nil); });
                 }
                 return;
             }
             NSString *url = response[@"data"][@"link"];
             if (!url) {
                 if (callback) {
                     NSDictionary *userInfo = @{
                         NSLocalizedDescriptionKey : @"Missing image URL"
                     };
                     NSError *error = [NSError errorWithDomain:ImgurAPIErrorDomain
                                                          code:ImgurAPIErrorMissingImageURL
                                                      userInfo:userInfo];
                     dispatch_async(dispatch_get_main_queue(), ^{ callback(error, nil); });
                 }
                 return;
             }
             [listOfURLs addObject:[NSURL URLWithString:url]];
         }
         if (callback) dispatch_async(dispatch_get_main_queue(), ^{ callback(nil, listOfURLs); });
     }];
}

@end


@implementation ImageResizeOperation

- (id)initWithImages:(NSArray *)images
{
    if (!(self = [super init])) return nil;
    _images = [images copy];
    return self;
}

- (void)main
{
    NSMutableArray *base64EncodedImageStrings = [NSMutableArray new];
    for (__strong UIImage *image in _images) {
        if ([self isCancelled]) return;
        if (image.imageOrientation != UIImageOrientationUp) {
            CGSize newSize = image.size;
            switch (image.imageOrientation) {
                case UIImageOrientationLeft:
                case UIImageOrientationLeftMirrored:
                case UIImageOrientationRight:
                case UIImageOrientationRightMirrored:
                    newSize = CGSizeMake(newSize.height, newSize.width);
                default:
                    break;
            }
            image = [image resizedImage:newSize interpolationQuality:kCGInterpolationHigh];
        }
        const NSUInteger TenMB = 10485760;
        NSData *data = UIImagePNGRepresentation(image);
        while ([data length] > TenMB && ![self isCancelled]) {
            CGSize newSize = CGSizeMake(image.size.width / 2, image.size.height / 2);
            image = [image resizedImage:newSize interpolationQuality:kCGInterpolationHigh];
            data = UIImagePNGRepresentation(image);
        }
        if ([self isCancelled]) return;
        [base64EncodedImageStrings addObject:[data base64EncodedString]];
    }
    self.base64EncodedImageStrings = base64EncodedImageStrings;
}

@end


NSString * const ImgurAPIErrorDomain = @"ImgurAPIErrorDomain";
