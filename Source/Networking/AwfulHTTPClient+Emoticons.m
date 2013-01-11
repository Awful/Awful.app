//
//  AwfulHTTPClient+Emoticons.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+Emoticons.h"
#import "AwfulModels.h"
#import "AwfulParsing+Emoticons.h"
#import "AwfulDataStack.h"

@implementation AwfulHTTPClient (Emoticons)
-(NSOperation *)emoticonListAndThen:(void (^)(NSError *))callback
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"misc.php?action=showsmilies"];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   EmoticonParsedInfo *parsedInfo = [[EmoticonParsedInfo alloc] initWithHTMLData:responseData];
                                                                   NSLog(@"parsedinfo%@",parsedInfo);
                                                                   //NSArray *msgs = [AwfulEmote parseEmoticonsWithData:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   //EmoticonListResponseBlock(msgs);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   //errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)cacheEmoticon:(AwfulEmoticon *)emoticon andThen:(void (^)(NSError *))callback
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:emoticon.urlString parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   //NSData *responseData = (NSData *)response;
                                                                   //[AwfulEmote cacheEmoticon:emote data:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   //EmoticonListResponseBlock(void);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   //errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}
@end
