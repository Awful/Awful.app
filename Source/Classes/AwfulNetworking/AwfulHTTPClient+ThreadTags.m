//
//  AwfulHTTPClient+ThreadTags.m
//  Awful
//
//  Created by me on 7/31/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+ThreadTags.h"
#import "AwfulThreadTag.h"

@implementation AwfulHTTPClient (ThreadTags)
-(NSOperation *)threadTagListForForum:(AwfulForum*)forum
                         onCompletion:(ThreadTagListResponseBlock)ThreadTagListResponseBlock
                                 onError:(AwfulErrorBlock)errorBlock
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"newthread.php?action=newthread&forumid=1"];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   NSArray *msgs = [AwfulThreadTag parseThreadTagsForForum:forum
                                                                                                                  withData:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   ThreadTagListResponseBlock(msgs);
                                                               }
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)cacheThreadTag:(AwfulThreadTag *)threadTag
                  onCompletion:(ThreadTagCacheResponseBlock)threadTagCacheResponseBlock
                       onError:(AwfulErrorBlock)errorBlock
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:threadTag.filename parameters:nil];
    urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   [AwfulThreadTag cacheThreadTag:threadTag data:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   //EmoticonListResponseBlock(void);
                                                               }
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}
@end
