//
//  AwfulErrorDomain.h
//  Awful
//
//  Created by Nolan Waite on 2013-03-08.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

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
} AwfulErrorCodes;
