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

+ (ImgurHTTPClient *)sharedClient
{
    static ImgurHTTPClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.imgur.com"]];
    });
    return instance;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self) {
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    }
    return self;
}

// TODO make cancelable
- (void)uploadImages:(NSArray *)images andThen:(void(^)(NSError *error, NSArray *urls))callback
{
    NSMutableArray *requests = [NSMutableArray new];
    for (UIImage *image in images) {
        NSData *dataForImage = UIImagePNGRepresentation(image);
        NSDictionary *parameters = @{
            @"key" : @"4b083e3139cadecd17153b69f3cd666c",
            @"image" : [dataForImage base64EncodedString]
        };
        [requests addObject:[self requestWithMethod:@"POST" path:@"/2/upload.json" parameters:parameters]];
    }
    NSMutableArray *listOfURLs = [NSMutableArray new];
    [self enqueueBatchOfHTTPRequestOperationsWithRequests:requests
                                            progressBlock:nil
                                          completionBlock:^(NSArray *listOfOperations)
    {
        for (AFJSONRequestOperation *operation in listOfOperations) {
            if (![operation isKindOfClass:[AFJSONRequestOperation class]]) {
                if (callback) {
                    NSDictionary *userInfo = @{
                        NSLocalizedDescriptionKey : @"An unknown error occurred",
                        NSUnderlyingErrorKey : operation.error
                    };
                    NSError *error = [NSError errorWithDomain:ImgurAPIErrorDomain
                                                         code:ImgurAPIErrorUnknown
                                                     userInfo:userInfo];
                    dispatch_async(dispatch_get_main_queue(), ^{ callback(error, nil); });
                }
                return;
            }
            NSDictionary *response = operation.responseJSON;
            if (!operation.hasAcceptableStatusCode) {
                if (callback) {
                    NSInteger errorCode = ImgurAPIErrorUnknown;
                    if (operation.response.statusCode == 400) {
                        errorCode = ImgurAPIErrorInvalidImage;
                    } else if (operation.response.statusCode == 403) {
                        errorCode = ImgurAPIErrorRateLimitExceeded;
                    }
                    NSString *message = response[@"error"][@"message"];
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
            NSString *url = response[@"upload"][@"links"][@"original"];
            if (!url) {
                if (callback) {
                    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"An unknown error occurred" };
                    NSError *error = [NSError errorWithDomain:ImgurAPIErrorDomain
                                                         code:ImgurAPIErrorUnknown
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

- (void)checkIfAnyImagesCanBeUploadedAndThen:(void(^)(BOOL canUploadAtLeastOneImage))callback
{
    [self getPath:@"/2/credits.json" parameters:nil success:^(AFHTTPRequestOperation *operation, id _)
    {
        NSDictionary *headers = [operation.response allHeaderFields];
        NSInteger creditsRemaining = [headers[@"X-RateLimit-Remaining"] integerValue];
        if (callback) dispatch_async(dispatch_get_main_queue(), ^{ callback(creditsRemaining > 10); });
    } failure:^(AFHTTPRequestOperation *operation, NSError *error)
    {
        if (callback) dispatch_async(dispatch_get_main_queue(), ^{ callback(NO); });
    }];
}

@end

NSString * const ImgurAPIErrorDomain = @"ImgurAPIErrorDomain";
