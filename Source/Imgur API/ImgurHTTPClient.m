//
//  ImgurHTTPClient.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-06.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ImgurHTTPClient.h"
#import "NSData+Base64.h"

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
    NSMutableArray *requests = [NSMutableArray new];
    for (UIImage *image in images) {
        NSData *imageData = UIImagePNGRepresentation(image);
        NSDictionary *dict = @{ @"image": [imageData base64EncodedString] };
        [requests addObject:[self requestWithMethod:@"POST" path:@"/3/image.json" parameters:dict]];
    }
    NSMutableArray *listOfURLs = [NSMutableArray new];
    [self enqueueBatchOfHTTPRequestOperationsWithRequests:requests
                                            progressBlock:nil
                                          completionBlock:^(NSArray *listOfOperations)
    {
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

NSString * const ImgurAPIErrorDomain = @"ImgurAPIErrorDomain";
