//
//  AwfulForumRefreshRequest.m
//  Awful
//
//  Created by Sean Berry on 11/13/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumRefreshRequest.h"
#import "TFHpple.h"
#import "AwfulParse.h"
#import "AwfulThread.h"
#import "AwfulUtil.h"

@implementation AwfulForumRefreshRequest

@synthesize threadList;

-(id)initWithAwfulThreadList : (AwfulThreadList *)aThreadList;
{    
    NSString *url_str = [NSString stringWithFormat:@"http://forums.somethingawful.com/%@", [aThreadList getURLSuffix]];
    if((self = [super initWithURL:[NSURL URLWithString:url_str]])) {
        self.threadList = aThreadList;
    }
    
    return self;
}

-(void)requestStarted
{
    [super requestStarted];
}

-(void)requestFinished
{
    [super requestFinished];
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];

    TFHpple *forum_data = [[TFHpple alloc] initWithHTMLData:converted];
    
    NSMutableArray *threads = [AwfulParse newThreadsFromForum:forum_data];
    
    [AwfulUtil saveThreadList:threads forForumId:[threadList getSaveID]];
    
    [threadList acceptThreads:threads];
}

- (void)failWithError:(NSError *)theError
{
    [super failWithError:theError];
    [self.threadList stop];
}

@end
