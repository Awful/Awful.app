//  InstapaperAPIClient.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AFHTTPClient.h"

// Instapaper simple API client.
@interface InstapaperAPIClient : AFHTTPClient

// Singleton instance.
+ (instancetype)client;

// Validate an Instapaper username and password.
//
// username - the username for the Instapaper account.
// password - the password for the Instapaper account. If the account has no password, any password
//            will work.
// callback - a block that's called after receiving a response:
//              error - an NSError in the InstapaperAPIErrorDomain on failure, or nil on success.
- (void)validateUsername:(NSString *)username
                password:(NSString *)password
                 andThen:(void (^)(NSError *error))callback;

// Add the URL to the stored Instapaper account.
//
// url - the URL to add.
// username - the username for the Instapaper account.
// password - the password for the Instapaper account, if any.
// callback - a block that's called after receiving a response:
//              error - an NSError in the InstapaperAPIErrorDomain on failure, or nil on success.
//
// If the URL already exists in the user's Instapaper account, it will be marked unread and sent to
// the top of the list. It will not be duplicated.
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
