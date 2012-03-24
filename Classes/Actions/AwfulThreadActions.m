//
//  AwfulThreadActions.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadActions.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulPostBoxController.h"
#import "AwfulAppDelegate.h"
//#import "ASIFormDataRequest.h"
#import "AwfulUtil.h"
#import "AwfulVoteActions.h"

typedef enum {
    AwfulThreadActionReply,
    AwfulThreadActionVote,
    AwfulThreadActionBookmarks,
    AwfulThreadActionScrollToBottom,
} AwfulThreadAction;

@implementation AwfulThreadActions

@synthesize page;

-(id)initWithAwfulPage:(AwfulPage *)aPage
{
    if((self=[super init])) {
        self.page = aPage;
        
        //[self.titles addObject:@"Reply"];
        [self.titles addObject:@"Vote"];
        
        if(self.page.isBookmarked) {
            [self.titles addObject:@"Remove From Bookmarks"];
        } else {
            [self.titles addObject:@"Add To Bookmarks"];
        }
        
        [self.titles addObject:@"Scroll To Bottom"];

    }
    return self;
}


-(NSString *)getOverallTitle
{
    return @"Thread Actions";
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{    
    /*if([self isCancelled:buttonIndex]) {
        [self.navigator setActions:nil];
        return;
    }
    
    if(buttonIndex == AwfulThreadActionVote) {
        
        AwfulVoteActions *vote = [[AwfulVoteActions alloc] initWithAwfulThread:self.page.thread];
        [self.navigator setActions:vote];
        
    } else if(buttonIndex == AwfulThreadActionReply) {
        
        AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:@""];
        [post_box setThread:self.page.thread];
        UIViewController *vc = getRootController();
        [vc presentModalViewController:post_box animated:YES];
        
    } else if(buttonIndex == AwfulThreadActionBookmarks) {
        
        if(self.page.isBookmarked) {
            [self removeBookmark];
        } else {
            [self addBookmark];
        }
        
    }
    if(buttonIndex != AwfulThreadActionVote) {
        [self.navigator setActions:nil];
    }*/
}

-(void)addBookmark
{/*
    ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
    req.userInfo = [NSDictionary dictionaryWithObject:@"Added to bookmarks." forKey:@"completionMsg"];
    
    [req setPostValue:@"1" forKey:@"json"];
    [req setPostValue:@"add" forKey:@"action"];
    [req setPostValue:self.page.thread.threadID forKey:@"threadid"];
    self.page.isBookmarked = YES;
    
    NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
    [bookmarked_threads addObject:self.page.thread];
    [AwfulUtil saveThreadList:bookmarked_threads forForumId:@"bookmarks"];
    
    loadRequestAndWait(req);*/
}

-(void)removeBookmark
{/*
    ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
    req.userInfo = [NSDictionary dictionaryWithObject:@"Removed from bookmarks." forKey:@"completionMsg"];
    
    [req setPostValue:@"1" forKey:@"json"];
    [req setPostValue:@"remove" forKey:@"action"];
    [req setPostValue:self.page.thread.threadID forKey:@"threadid"];
    self.page.isBookmarked = NO;
    
    NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
    AwfulThread *found = nil;
    for(AwfulThread *thread in bookmarked_threads) {
        if([thread.threadID isEqualToString:self.page.thread.threadID]) {
            found = thread;
        }
    }
    [bookmarked_threads removeObject:found];
    [AwfulUtil saveThreadList:bookmarked_threads forForumId:@"bookmarks"];
    
    loadRequestAndWait(req);*/
}

@end
