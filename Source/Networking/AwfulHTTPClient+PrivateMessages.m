//
//  AwfulHTTPClient+PrivateMessages.m
//  Awful
//
//  Created by me on 7/23/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulParsing+PrivateMessages.h"
#import "AwfulDataStack.h"
#import "AwfulModels.h"
#import "AwfulThreadTags.h"
#import "AwfulJSONOrScrapeOperation.h"

@implementation AwfulHTTPClient (PrivateMessages)

-(NSOperation *)privateMessageListAndThen:(void (^)(NSError *error, NSArray *messages))callback
{
    //return nil;
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"private.php" parameters:@{}];
    //urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AwfulJSONOrScrapeOperation *op = (AwfulJSONOrScrapeOperation*)[self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(id _, id data)
                                  {
                                        #warning fixme there is no self.parsequeue
                                      //dispatch_async(self.parseQueue, ^{
                                          //NSArray *infos = [PrivateMessageParsedInfo messagesWithHTMLData:data];
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              NSArray *pms = [AwfulPrivateMessage privateMessagesCreatedOrUpdatedWithParsedInfo:data];
                                              [[AwfulDataStack sharedDataStack] save];
                                              if (callback) callback(nil, pms);
                                          });
                                      //});
                                  } failure:^(id _, NSError *error) {
                                      if (callback) callback(error, nil);
                                  }];
    
    op.createParsedInfoBlock = ^id(NSData * data) {
        return [PrivateMessageParsedInfo messagesWithHTMLData:data];
    };

    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)loadPrivateMessage:(AwfulPrivateMessage*)message
                           andThen:(void (^)(NSError *error, AwfulPrivateMessage *message))callback
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"private.php?action=show&privatemessageid=%@", message.messageID];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   [PrivateMessageParsedInfo parsePM:message withData:responseData];
                                                                   callback(nil, message);
                                                               }
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   callback(error, nil);
                                                                   
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)sendPrivateMessageTo:(NSString*)username
                             subject:(NSString*)subject
                                icon:(NSString*)iconName
                                text:(NSString*)contentBBCode
                             andThen:(void (^)(NSError *error, AwfulPrivateMessage *message))callback
{
    #warning fixme need to pass in id of thread tag
    NSDictionary *params = @{
                             @"touser": username,
                             @"title": subject,
                             //@"iconid": iconName,
                             @"message": contentBBCode,
                             @"action": @"dosend",
                             @"submit": @"Send Message",
                             @"client": @"awful iOS test"
                             };
    //return nil;
    
    
    NSURLRequest *postRequest = [self requestWithMethod:@"POST" path:@"private.php" parameters:params];
    
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:postRequest
                                                                    success:^(AFHTTPRequestOperation *operation, id response) {
                                                                        if (callback) callback(nil,nil);
                                                                    } 
                                                                    failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                        if (callback) callback(error,nil);
                                                                    }
                                       ];
       
    [self enqueueHTTPRequestOperation:op];

    return (NSOperation *)op;
}

@end
