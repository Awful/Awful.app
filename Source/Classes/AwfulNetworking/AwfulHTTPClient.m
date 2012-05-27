//
//  AwfulHTTPClient.m
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"
#import "AwfulForum.h"
#import "AwfulForum+AwfulMethods.h"
#import "TFHpple.h"
#import "AwfulThread.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulPage.h"
#import "AwfulPageDataController.h"
#import "AwfulUser.h"
#import "AwfulUser+AwfulMethods.h"
#import "AwfulPageTemplate.h"
#import "NSString+HTML.h"
#import "NetworkingFileLogger.h"

static const int NetworkLogLevel = LOG_LEVEL_VERBOSE;

@implementation AwfulHTTPClient

+ (id)sharedClient {
    static AwfulHTTPClient *__sharedClient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedClient = [[AwfulHTTPClient alloc] initWithBaseURL:
                            [NSURL URLWithString:@"http://forums.somethingawful.com/"]];
    });
    
    return __sharedClient;
}

+ (DDFileLogger *)logger
{
    static DDFileLogger *logger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[NetworkingFileLogger alloc] init];
        [DDLog addLogger:logger];
    });
    return logger;
}

-(NSOperation *)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"forumdisplay.php?forumid=%@&perpage=40&pagenumber=%u", forum.forumID, pageNum];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
        success:^(AFHTTPRequestOperation *operation, id response) {
            NetworkLogInfo(@"completed %@", THIS_METHOD);
            if(pageNum == 1) {
                [AwfulThread removeOldThreadsForForum:forum];
                [ApplicationDelegate saveContext];
            }
            
            NSData *responseData = (NSData *)response;
            NSMutableArray *threads = [AwfulThread parseThreadsWithData:responseData forForum:forum];
            [ApplicationDelegate saveContext];
            threadListResponseBlock(threads);
        } 
        failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NetworkLogInfo(@"erred %@", THIS_METHOD);
            errorBlock(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)threadListForBookmarksAtPageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock) errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"bookmarkthreads.php?action=view&perpage=40&pagenumber=%d", pageNum];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           if(pageNum == 1) {
               [AwfulThread removeBookmarkedThreads];
           }
           
           NSData *responseData = (NSData *)response;
           NSMutableArray *threads = [AwfulThread parseBookmarkedThreadsWithData:responseData];
           [ApplicationDelegate saveContext];
           threadListResponseBlock(threads);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *append = @"";
    switch(destinationType) {
        case AwfulPageDestinationTypeFirst:
            append = @"";
            break;
        case AwfulPageDestinationTypeLast:
            append = @"&goto=lastpost";
            break;
        case AwfulPageDestinationTypeNewpost:
            append = @"&goto=newpost";
            break;
        case AwfulPageDestinationTypeSpecific:
            append = [NSString stringWithFormat:@"&pagenumber=%d", pageNum];
            break;
        default:
            append = @"";
            break;
    }
    
    NSString *path = [[NSString alloc] initWithFormat:@"showthread.php?threadid=%@%@", thread.threadID, append];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           NSData *data = (NSData *)response;
           AwfulPageDataController *data_controller = [[AwfulPageDataController alloc] initWithResponseData:data pageURL:[urlRequest URL]];
           pageResponseBlock(data_controller);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)userInfoRequestOnCompletion : (UserResponseBlock)userResponseBlock onError : (AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"member.php?action=editprofile";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           
           AwfulUser *user = [AwfulUser currentUser];
           
           if(user == nil) {
               errorBlock(nil);
               return;
           }
           
           NSData *data = (NSData *)response;
           NSString *html_str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
           if(html_str == nil) {
               // attempt to avoid some crashes
               errorBlock(nil);
               return;
           }
           
           NSError *regex_error = nil;
           NSRegularExpression *userid_regex = [NSRegularExpression regularExpressionWithPattern:@"userid=(\\d+)" options:NSRegularExpressionCaseInsensitive error:&regex_error];
           
           if(regex_error != nil) {
               NSLog(@"%@", [regex_error localizedDescription]);
           }
           
           NSTextCheckingResult *userid_result = [userid_regex firstMatchInString:html_str options:0 range:NSMakeRange(0, [html_str length])];
           NSRange userid_range = [userid_result rangeAtIndex:1];
           if(userid_range.location != NSNotFound) {
               NSString *user_id = [html_str substringWithRange:userid_range];
               int user_id_int = [user_id intValue];
               if(user_id_int != 0) {
                   [user setUserID:user_id];
               }
           }
           
           NSRegularExpression *username_regex = [NSRegularExpression regularExpressionWithPattern:@"Edit Profile - (.*?)<" options:NSRegularExpressionCaseInsensitive error:&regex_error];
           
           if(regex_error != nil) {
               NSLog(@"%@", [regex_error localizedDescription]);
           }
           
           NSTextCheckingResult *username_result = [username_regex firstMatchInString:html_str options:0 range:NSMakeRange(0, [html_str length])];
           NSRange username_range = [username_result rangeAtIndex:1];
           if(username_range.location != NSNotFound) {
               NSString *username = [html_str substringWithRange:username_range];
               username = [username stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
               [user setUserName:username];
           }
           
           [ApplicationDelegate saveContext];
           userResponseBlock(user);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)addBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           errorBlock(nil);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)removeBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           errorBlock(nil);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)forumsListOnCompletion : (ForumsListResponseBlock)forumsListResponseBlock onError : (AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"forumdisplay.php?forumid=1";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           NSData *data = (NSData *)response;
           NSMutableArray *forums = [AwfulForum parseForums:data];
           if (forumsListResponseBlock) {
               forumsListResponseBlock(forums);
           }
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           if (errorBlock) {
               errorBlock(error);
           }
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)replyToThread : (AwfulThread *)thread withText : (NSString *)text onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           errorBlock(nil);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)editContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           errorBlock(nil);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)quoteContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           errorBlock(nil);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)editPost : (AwfulPost *)post withContents : (NSString *)contents onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NetworkLogInfo(@"completed %@", THIS_METHOD);
           errorBlock(nil);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           NetworkLogInfo(@"erred %@", THIS_METHOD);
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)submitVote : (int)value forThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   errorBlock(nil);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)processMarkSeenLink : (NSString *)markSeenLink onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   errorBlock(nil);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)markThreadUnseen : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = @"";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   errorBlock(nil);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

@end
