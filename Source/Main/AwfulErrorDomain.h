//  AwfulErrorDomain.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

// All Awful-specific errors have this domain and an error code specified under AwfulErrorCodes.
extern NSString * const AwfulErrorDomain;

extern const struct AwfulErrorCodes
{
    // When an attempt to log in fails because of the username or password.
    // There may be an underlying error in the AFNetworkingErrorDomain.
    NSInteger badUsernameOrPassword;
    
    // Some action isn't allowed because the thread is closed.
    NSInteger threadIsClosed;
    
    // Could not parse the response from SA.
    NSInteger parseError;
    
    // Migrating the Core Data store failed.
    NSInteger dataMigrationError;
    
    // Could not find the Core Data store.
    NSInteger missingDataStore;
    
    // Don't have permission to do it.
    NSInteger forbidden;
} AwfulErrorCodes;
