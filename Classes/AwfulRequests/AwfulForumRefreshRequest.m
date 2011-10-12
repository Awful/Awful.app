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

-(id)initWithAwfulThreadList : (AwfulThreadList *)in_list;
{
    threadList = [in_list retain];
    
    NSString *url_str = [NSString stringWithFormat:@"http://forums.somethingawful.com/%@", [threadList getURLSuffix]];
    self = [super initWithURL:[NSURL URLWithString:url_str]];
    
    return self;
}

-(void)dealloc
{
    [threadList release];
    [super dealloc];
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
    [raw_s release];
    
    NSMutableArray *threads = [AwfulParse newThreadsFromForum:forum_data];
    [forum_data release];
    
    [AwfulUtil saveThreadList:threads forForumId:[threadList getSaveID]];
    
    [threadList acceptThreads:threads];
    [threads release];
}

- (void)failWithError:(NSError *)theError
{
    [super failWithError:theError];
    [self.threadList stop];
}

@end
