//
//  AwfulYOSPOSHTTPRequestOperation.m
//  Awful
//
//  Created by me on 8/9/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulYOSPOSHTTPRequestOperation.h"


//send messages for connection events, for refresh control
@implementation AwfulYOSPOSHTTPRequestOperation

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response {
    NSNumber *code = [NSNumber numberWithInt:[(NSHTTPURLResponse*)response statusCode]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulYOSPOSHTTPRequestNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObject:code forKey:@"code"]
     ];

    [super connection:connection didReceiveResponse:response];
}

-(void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulYOSPOSHTTPDataNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:data.length]
                                                                                           forKey:@"length"
                                                                ]
     ];
    [super connection:connection didReceiveData:data];
}

@end
