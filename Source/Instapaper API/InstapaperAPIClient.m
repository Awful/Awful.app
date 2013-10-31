//  InstapaperAPIClient.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "InstapaperAPIClient.h"
#import <AFNetworking/AFNetworking.h>

@implementation InstapaperAPIClient
{
    AFHTTPSessionManager *_HTTPManager;
}

+ (instancetype)client
{
    static InstapaperAPIClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    NSURL *baseURL = [NSURL URLWithString:@"https://www.instapaper.com/api/"];
    _HTTPManager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseURL];
    return self;
}

- (void)validateUsername:(NSString *)username
                password:(NSString *)password
                 andThen:(void (^)(NSError *error))callback
{
    [_HTTPManager POST:@"authenticate"
            parameters:@{ @"username": username, @"password": password ?: @"" }
               success:^(NSURLSessionDataTask *task, id responseObject) {
                   if (callback) callback(nil);
               } failure:^(NSURLSessionDataTask *task, NSError *underlyingError) {
                   if (!callback) return;
                   NSInteger errorCode = InstapaperAPIErrorCodes.unknownError;
                   NSString *description = @"An unknown error occurred";
                   if (((NSHTTPURLResponse *)task.response).statusCode == 403) {
                       errorCode = InstapaperAPIErrorCodes.invalidUsernameOrPassword;
                       description = @"Invalid username or password";
                   }
                   NSDictionary *userInfo = @{ NSUnderlyingErrorKey: underlyingError,
                                               NSLocalizedDescriptionKey: description };
                   NSError *error = [NSError errorWithDomain:InstapaperAPIErrorDomain
                                                        code:errorCode
                                                    userInfo:userInfo];
                   callback(error);
               }];
}

- (void)addURL:(NSURL *)url
   forUsername:(NSString *)username
      password:(NSString *)password
       andThen:(void (^)(NSError *error))callback
{
    AFHTTPRequestSerializer *requestSerializer = [_HTTPManager.requestSerializer copy];
    [requestSerializer setAuthorizationHeaderFieldWithUsername:username password:password ?: @""];
    NSURL *requestURL = [NSURL URLWithString:@"add" relativeToURL:_HTTPManager.baseURL];
    NSURLRequest *request = [requestSerializer requestWithMethod:@"POST"
                                                       URLString:requestURL.absoluteString
                                                      parameters:@{ @"url": url.absoluteString }];
    [_HTTPManager dataTaskWithRequest:request
                    completionHandler:^(NSURLResponse *response, id responseObject, NSError *underlyingError)
    {
        if (!callback) return;
        if (!underlyingError) {
            callback(nil);
            return;
        }
        NSInteger errorCode = InstapaperAPIErrorCodes.unknownError;
        NSString *description = @"An unknown error occurred";
        if (((NSHTTPURLResponse *)response).statusCode == 403) {
            errorCode = InstapaperAPIErrorCodes.invalidUsernameOrPassword;
            description = @"Invalid username or password";
        } else if (((NSHTTPURLResponse *)response).statusCode == 400) {
            errorCode = InstapaperAPIErrorCodes.rateLimitExceeded;
            description = @"Rate limit exceeded";
        }
        NSDictionary *userInfo = @{ NSUnderlyingErrorKey: underlyingError,
                                    NSLocalizedDescriptionKey: description };
        NSError *error = [NSError errorWithDomain:InstapaperAPIErrorDomain
                                             code:errorCode
                                         userInfo:userInfo];
        callback(error);
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
