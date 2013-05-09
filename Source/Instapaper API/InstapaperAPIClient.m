//
//  InstapaperAPIClient.m
//  Awful
//
//  Created by Nolan Waite on 2013-05-08.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "InstapaperAPIClient.h"
#import "AFHTTPRequestOperation.h"

// http://www.instapaper.com/api/simple
@implementation InstapaperAPIClient

+ (instancetype)client
{
    static InstapaperAPIClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithBaseURL:
                    [NSURL URLWithString:@"https://www.instapaper.com/api/"]];
    });
    return instance;
}

- (void)validateUsername:(NSString *)username
                password:(NSString *)password
                 andThen:(void (^)(NSError *error))callback
{
    password = password ?: @"";
    [self postPath:@"authenticate"
        parameters:@{ @"username": username, @"password": password }
           success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *underlyingError) {
        if (callback) {
            NSDictionary *userInfo = @{
                NSUnderlyingErrorKey: underlyingError,
                NSLocalizedDescriptionKey: @"An unknown error occurred",
            };
            NSError *error = [NSError errorWithDomain:InstapaperAPIErrorDomain
                                                 code:InstapaperAPIErrorCodes.unknownError
                                             userInfo:userInfo];
            callback(error);
        }
    }];
}

- (void)addURL:(NSURL *)url
   forUsername:(NSString *)username
      password:(NSString *)password
       andThen:(void (^)(NSError *error))callback
{
    [self clearAuthorizationHeader];
    [self setAuthorizationHeaderWithUsername:username password:password ?: @""];
    [self postPath:@"add"
        parameters:@{ @"url": [url absoluteString] }
           success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *underlyingError) {
        if (callback) {
            NSInteger errorCode = InstapaperAPIErrorCodes.unknownError;
            NSString *description = @"An unknown error occurred";
            if (operation.response.statusCode == 403) {
                errorCode = InstapaperAPIErrorCodes.invalidUsernameOrPassword;
                description = @"Invalid username or password";
            } else if (operation.response.statusCode == 400) {
                errorCode = InstapaperAPIErrorCodes.rateLimitExceeded;
                description = @"Rate limit exceeded";
            }
            NSDictionary *userInfo = @{
                NSUnderlyingErrorKey: underlyingError,
                NSLocalizedDescriptionKey: description,
            };
            NSError *error = [NSError errorWithDomain:InstapaperAPIErrorDomain
                                                 code:errorCode
                                             userInfo:userInfo];
            callback(error);
        }
    }];
}


@end

NSString * const InstapaperAPIErrorDomain = @"InstapaperAPIErrorDomain";

const struct InstapaperAPIErrorCodes InstapaperAPIErrorCodes =
{
    .unknownError = -1,
    .invalidUsernameOrPassword = -1000,
    .rateLimitExceeded = -1001,
};
