//
//  AwfulHTTPOperation.h
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulHTTPOperation : NSOperation

// Designated initializer.
- (id)initWithURL:(NSURL *)url;

@property (readonly, strong) NSURLRequest *request;

@property (readonly, strong) NSURLResponse *response;

// nil on failure
@property (readonly, strong) NSData *responseData;

// nil on success
@property (readonly, strong) NSError *error;

@end
