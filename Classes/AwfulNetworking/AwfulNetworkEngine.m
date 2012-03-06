//
//  AwfulNetworkEngine.m
//  Awful
//
//  Created by Sean Berry on 2/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulNetworkEngine.h"
#import "AwfulForum.h"
#import "TFHpple.h"
#import "AwfulParse.h"
#import "AwfulThread.h"
#import "AwfulPage.h"
#import "AwfulPageDataController.h"
#import "AwfulUser.h"

@implementation AwfulNetworkEngine

-(MKNetworkOperation *)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock) errorBlock
{
    NSString *path = [NSString stringWithFormat:@"forumdisplay.php?forumid=%@&pagenumber=%u", forum.forumID, pageNum];
    MKNetworkOperation *op = [self operationWithPath:path];
    
    [op onCompletion:^(MKNetworkOperation *completedOperation) {
        
        NSData *responseData = [completedOperation responseData];
        NSMutableArray *threads = [AwfulParse parseThreadsFromForumData:responseData];
        threadListResponseBlock(threads);
        
    } onError:^(NSError *error) {
        
        errorBlock(error);
    }];
    
    [self enqueueOperation:op];
    return op;
}


-(MKNetworkOperation *)threadListForBookmarksAtPageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock) errorBlock
{
    NSString *path = [NSString stringWithFormat:@"bookmarkthreads.php?pagenumber=%u", pageNum];
    MKNetworkOperation *op = [self operationWithPath:path];
    
    [op onCompletion:^(MKNetworkOperation *completedOperation) {
        
        NSData *responseData = [completedOperation responseData];
        NSMutableArray *threads = [AwfulParse parseThreadsFromForumData:responseData];
        threadListResponseBlock(threads);
        
    } onError:^(NSError *error) {
        
        errorBlock(error);
    }];
    
    [self enqueueOperation:op];
    return op;
}

-(MKNetworkOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(MKNKErrorBlock)errorBlock
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
    MKNetworkOperation *op = [self operationWithPath:path];
    
    [op onCompletion:^(MKNetworkOperation *completedOperation) {
        
        AwfulPageDataController *data_controller = [[AwfulPageDataController alloc] initWithResponseData:[completedOperation responseData] pagePath:path];
        pageResponseBlock(data_controller);
        
    } onError:^(NSError *error) {
        
        errorBlock(error);
    }];
    
    [self enqueueOperation:op];
    return op;
}

-(MKNetworkOperation *)userInfoRequestOnCompletion : (UserResponseBlock)userResponseBlock onError : (MKNKErrorBlock)errorBlock
{
    NSString *path = @"member.php?action=editprofile";
    MKNetworkOperation *op = [self operationWithPath:path];
    
    [op onCompletion:^(MKNetworkOperation *completedOperation) {
        
        /*TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:[completedOperation responseData]];
        NSArray *options_elements = [page_data search:@"//select[@name='umaxposts']//option"];
        
        for(TFHppleElement *el in options_elements) {
            if([el objectForKey:@"selected"] != nil) {
                NSString *val = [el objectForKey:@"value"];
                int ppp = [val intValue];
                if(ppp != 0) {
                    [[AwfulUser currentUser] setPostsPerPage:ppp];
                }
            }
        }*/
        
        AwfulUser *user = [[AwfulUser alloc] init];
        NSString *html_str = [completedOperation responseString];
        
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
                [user setUserID:[NSNumber numberWithInt:user_id_int]];
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
        
        userResponseBlock(user);
        
    } onError:^(NSError *error) {
        errorBlock(error);
    }];
    
    [self enqueueOperation:op];
    return op;
}

@end
