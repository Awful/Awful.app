//
//  AwfulScrapeOperation.m
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulScrapeOperation.h"
#import "AwfulHTTPOperation.h"

@interface AwfulScrapeOperation ()

@property (strong) NSError *error;

@property (readonly, nonatomic) AwfulHTTPOperation *httpOperation;

@end

@implementation AwfulScrapeOperation

@synthesize error = _error;

- (AwfulHTTPOperation *)httpOperation
{
    return [self.dependencies objectAtIndex:0];
}

- (void)main
{
    if ([self isCancelled])
        return;
    if ([self.httpOperation isCancelled])
    {
        [self cancel];
        return;
    }
    if (self.httpOperation.error)
    {
        self.error = self.httpOperation.error;
        return;
    }
    // TODO scrape like a mofo using self.httpOperation.responseData
}

@end
