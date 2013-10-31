//  InstapaperAPIClient.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

/**
 * An InstapaperAPIClient adds URLs to Instapaper using the simple API. http://www.instapaper.com/api/simple
 */
@interface InstapaperAPIClient : NSObject

/**
 * Convenient singleton instance.
 */
+ (instancetype)client;

/**
 * @param callback A block that's called after validation that takes one parameter: an NSError object in the InstapaperAPIErrorDomain on failure, or nil on success.
 */
- (void)validateUsername:(NSString *)username
                password:(NSString *)password
                 andThen:(void (^)(NSError *error))callback;

/**
 * @param callback A block that's called after adding the URL that takes one parameter: an NSError object in the InstapaperAPIErrorDomain on failure, or nil on success.
 *
 * If the URL already exists in the user's Instapaper account, it will be marked unread and sent to the top of the list. It will not be duplicated.
 */
- (void)addURL:(NSURL *)url
   forUsername:(NSString *)username
      password:(NSString *)password
       andThen:(void (^)(NSError *error))callback;

@end


extern NSString * const InstapaperAPIErrorDomain;

extern const struct InstapaperAPIErrorCodes
{
    // Not sure what went wrong. There may be an underlying error in the AFNetworingErrorDomain.
    NSInteger unknownError;
    
    // Missing or invalid username and/or password.
    NSInteger invalidUsernameOrPassword;
    
    // Too many submissions in too short a time.
    NSInteger rateLimitExceeded;
} InstapaperAPIErrorCodes;
