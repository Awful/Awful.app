//
//  AwfulHTTPClient.m
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"
#import "AwfulForum+AwfulMethods.h"
#import "TFHpple.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulPage.h"
#import "AwfulPageDataController.h"
#import "AwfulPageTemplate.h"
#import "NSString+HTML.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "AFHTTPRequestOperation.h"

@implementation AwfulHTTPClient

+ (id)sharedClient {
    static AwfulHTTPClient *__sharedClient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedClient = [[AwfulHTTPClient alloc] initWithBaseURL:
                            [NSURL URLWithString:@"http://forums.somethingawful.com/"]];
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    });
    
    return __sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self) {
        self.stringEncoding = NSWindowsCP1252StringEncoding;
    }
    return self;
}

-(NSOperation *)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *path = [NSString stringWithFormat:@"forumdisplay.php?forumid=%@&perpage=40&pagenumber=%u", forum.forumID, pageNum];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
        success:^(AFHTTPRequestOperation *operation, id response) {
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
            errorBlock(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)threadListForBookmarksAtPageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock) errorBlock
{
    NSString *path = [NSString stringWithFormat:@"bookmarkthreads.php?action=view&perpage=40&pagenumber=%d", pageNum];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if(pageNum == 1) {
               [AwfulThread removeBookmarkedThreads];
           }
           
           NSData *responseData = (NSData *)response;
           NSMutableArray *threads = [AwfulThread parseBookmarkedThreadsWithData:responseData];
           [ApplicationDelegate saveContext];
           threadListResponseBlock(threads);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(AwfulErrorBlock)errorBlock
{
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
           NSURLResponse *urlResponse = [operation response];
           NSURL *lastURL = [urlResponse URL];
           NSData *data = (NSData *)response;
           AwfulPageDataController *data_controller = [[AwfulPageDataController alloc] initWithResponseData:data pageURL:lastURL];
           pageResponseBlock(data_controller);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)userInfoRequestOnCompletion : (UserResponseBlock)userResponseBlock onError : (AwfulErrorBlock)errorBlock
{
    NSString *path = @"member.php?action=editprofile";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           AwfulUser *user = AwfulSettings.settings.currentUser;
           
           if(user == nil) {
               errorBlock(nil);
               return;
           }
           
           NSData *data = (NSData *)response;
           NSString *html_str = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
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
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

typedef enum BookmarkAction {
    AddBookmark,
    RemoveBookmark,
} BookmarkAction;

- (NSOperation *)modifyBookmark:(BookmarkAction)action withThread:(AwfulThread *)thread onCompletion:(CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:@"1" forKey:@"json"];
    [dict setObject:(action == AddBookmark ? @"add" : @"remove") forKey:@"action"];
    [dict setObject:thread.threadID forKey:@"threadid"];
    NSString *path = @"bookmarkthreads.php";
    NSURLRequest *urlRequest = [self requestWithMethod:@"POST" path:path parameters:dict];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)addBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    return [self modifyBookmark:AddBookmark withThread:thread onCompletion:completionBlock onError:errorBlock];
}

-(NSOperation *)removeBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    return [self modifyBookmark:RemoveBookmark withThread:thread onCompletion:completionBlock onError:errorBlock];
}

-(NSOperation *)forumsListOnCompletion : (ForumsListResponseBlock)forumsListResponseBlock onError : (AwfulErrorBlock)errorBlock
{
    // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list
    // of forums. We'll use the Comedy Goldmine as it's generally available (even when signed out)
    // and hopefully it's not much of a burden since threads rarely get goldmined.
    NSString *path = @"forumdisplay.php?forumid=21";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NSData *data = (NSData *)response;
           NSArray *forums = [AwfulForum parseForums:data];
           if (forumsListResponseBlock) {
               forumsListResponseBlock([forums mutableCopy]);
           }
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) {
               errorBlock(error);
           }
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)replyToThread : (AwfulThread *)thread withText : (NSString *)text onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    NSString *path = [NSString stringWithFormat:@"newreply.php?s=&action=newreply&threadid=%@", thread.threadID];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NSData *data = (NSData *)response;
           NSString *rawString = [[NSString alloc] initWithData:data encoding:self.stringEncoding];
           NSData *converted = [rawString dataUsingEncoding:NSUTF8StringEncoding];
           TFHpple *pageData = [[TFHpple alloc] initWithHTMLData:converted];
           
           TFHppleElement *formkeyElement = [pageData searchForSingle:@"//input[@name='formkey']"];
           TFHppleElement *formcookieElement = [pageData searchForSingle:@"//input[@name='form_cookie']"];
           
           NSString *formkey = [formkeyElement objectForKey:@"value"];
           NSString *formcookie = [formcookieElement objectForKey:@"value"];
           TFHppleElement *bookmarkElement = [pageData searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
           
           NSMutableDictionary *dict = [NSMutableDictionary dictionary];
           
           if(bookmarkElement != nil) {
               NSString *bookmark = [bookmarkElement objectForKey:@"value"];
               [dict setValue:bookmark forKey:@"bookmark"];
           }
           
           [dict setValue:thread.threadID forKey:@"threadid"];
           [dict setValue:formkey forKey:@"formkey"];
           [dict setValue:formcookie forKey:@"form_cookie"];
           [dict setValue:@"postreply" forKey:@"action"];
           [dict setValue:text forKey:@"message"];
           [dict setValue:@"yes" forKey:@"parseurl"];
           [dict setValue:@"Submit Reply" forKey:@"submit"];
           
           NSURLRequest *postRequest = [self requestWithMethod:@"POST" path:@"newreply.php" parameters:dict];
           AFHTTPRequestOperation *finalOp = [self HTTPRequestOperationWithRequest:postRequest 
                success:^(AFHTTPRequestOperation *operation, id response) {
                    if (completionBlock) completionBlock();
                } 
                failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    if (errorBlock) errorBlock(error);
                }];
           
           [self enqueueHTTPRequestOperation:finalOp];
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

typedef enum PostContentType {
EditPostContent,
QuotePostContent,
} PostContentType;

-(NSOperation *)contentsForPost : (AwfulPost *)post postType : (PostContentType)postType onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *path;
    if(postType == EditPostContent) {
        path = [NSString stringWithFormat:@"editpost.php?action=editpost&postid=%@", post.postID];
    } else if(postType == QuotePostContent) {
        path = [NSString stringWithFormat:@"newreply.php?action=newreply&postid=%@", post.postID];
    } else {
        return nil;
    }
    
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NSData *data = (NSData *)response;
           NSString *rawString = [[NSString alloc] initWithData:data encoding:self.stringEncoding];
           NSData *converted = [rawString dataUsingEncoding:NSUTF8StringEncoding];
           TFHpple *base = [[TFHpple alloc] initWithHTMLData:converted];
           
           TFHppleElement *quoteElement = [base searchForSingle:@"//textarea[@name='message']"];
           postContentResponseBlock([quoteElement content]);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)editContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    return [self contentsForPost:post postType:EditPostContent onCompletion:postContentResponseBlock onError:errorBlock];
}

-(NSOperation *)quoteContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    return [self contentsForPost:post postType:QuotePostContent onCompletion:postContentResponseBlock onError:errorBlock];
}

-(NSOperation *)editPost : (AwfulPost *)post withContents : (NSString *)contents onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *path = [NSString stringWithFormat:@"editpost.php?action=editpost&postid=%@", post.postID];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NSData *data = (NSData *)response;
           NSString *rawString = [[NSString alloc] initWithData:data encoding:self.stringEncoding];
           NSData *converted = [rawString dataUsingEncoding:NSUTF8StringEncoding];
           TFHpple *pageData = [[TFHpple alloc] initWithHTMLData:converted];
           
           NSMutableDictionary *dict = [NSMutableDictionary dictionary];
           
           TFHppleElement *bookmarkElement = [pageData searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
           if(bookmarkElement != nil) {
               NSString *bookmark = [bookmarkElement objectForKey:@"value"];
               [dict setValue:bookmark forKey:@"bookmark"];
           }
           
           [dict setValue:@"updatepost" forKey:@"action"];
           [dict setValue:@"Save Changes" forKey:@"submit"];
           [dict setValue:post.postID forKey:@"postid"];
           [dict setValue:contents forKey:@"message"];
           
           NSURLRequest *postRequest = [self requestWithMethod:@"POST" path:@"editpost.php" parameters:dict];
           AFHTTPRequestOperation *finalOp = [self HTTPRequestOperationWithRequest:postRequest 
               success:^(AFHTTPRequestOperation *operation, id response) {
                   if (completionBlock) completionBlock();
               } 
               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                   if (errorBlock) errorBlock(error);
               }];
           
           [self enqueueHTTPRequestOperation:finalOp];

       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)submitVote : (int)value forThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    int voteValue = MAX(5, MIN(1, value));
    [dict setValue:[NSNumber numberWithInt:voteValue] forKey:@"vote"];
    [dict setValue:thread.threadID forKey:@"threadid"];
    
    NSURLRequest *urlRequest = [self requestWithMethod:@"POST" path:@"threadrate.php" parameters:dict];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)processMarkSeenLink : (NSString *)markSeenLink onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *path = markSeenLink;
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)markThreadUnseen : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:thread.threadID forKey:@"threadid"];
    [dict setValue:@"resetseen" forKey:@"action"];
    [dict setValue:@"1" forKey:@"json"];
    
    NSString *path = @"showthread.php";
    NSURLRequest *urlRequest = [self requestWithMethod:@"POST" path:path parameters:dict];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

@end
