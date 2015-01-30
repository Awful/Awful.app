//  AwfulErrorDomain.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

/// All Awful-specific errors have this domain and an error code specified under AwfulErrorCodes.
extern NSString * const AwfulErrorDomain;

extern const struct AwfulErrorCodes
{
    /// When an attempt to log in fails because of the username or password. There may be an underlying error in the AFNetworkingErrorDomain.
    NSInteger badUsernameOrPassword;
    
    /// Some action isn't allowed because the thread is closed.
    NSInteger threadIsClosed;
    
    /// Thread is archived and user doesn't have access.
    NSInteger archivesRequired;
    
    /// Could not parse the response from SA.
    NSInteger parseError;
    
    /// SA's database is down.
    NSInteger databaseUnavailable;
    
    /// Migrating the Core Data store failed.
    NSInteger dataMigrationError;
    
    /// Could not find the Core Data store.
    NSInteger missingDataStore;
    
    /// Don't have permission to do it.
    NSInteger forbidden;
    
    /// Server didn't give us anything useful. == NSURLErrorBadServerResponse
    NSInteger badServerResponse;
} AwfulErrorCodes;
