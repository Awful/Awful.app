//
//  AwfulHTTPOperation.m
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPOperation.h"

@interface AwfulHTTPOperation ()

@property (strong) NSURLRequest *request;

@property (strong) NSURLResponse *response;

@property (strong) NSData *responseData;

@property (strong) NSError *error;

@end

@implementation AwfulHTTPOperation

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self)
    {
        self.request = [NSURLRequest requestWithURL:url];
    }
    return self;
}

@synthesize request = _request;
@synthesize response = _response;
@synthesize responseData = _responseData;
@synthesize error = _error;

- (void)main
{
    @autoreleasepool {
        if ([self isCancelled])
            return;
        NSURLResponse *response;
        NSError *error;
        // TODO check http response code
        self.responseData = [NSURLConnection sendSynchronousRequest:self.request
                                                  returningResponse:&response
                                                              error:&error];
        self.response = response;
        if (!self.responseData)
            self.error = error;
    }
}

@end
