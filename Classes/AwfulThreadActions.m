//
//  AwfulThreadActions.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadActions.h"
#import "AwfulNavigator.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulPageNavController.h"
#import "AwfulPostBoxController.h"
#import "AwfulAppDelegate.h"
#import "ASIFormDataRequest.h"
#import "AwfulUtil.h"
#import "AwfulVoteActions.h"

typedef enum {
    AwfulThreadActionScrollToBottom,
    AwfulThreadActionSpecificPage,
    AwfulThreadActionVote,
    AwfulThreadActionReply,
    AwfulThreadActionBookmarks,
    AwfulThreadActionNextPage
} AwfulThreadAction;

@implementation AwfulThreadActions

@synthesize page = _page;

-(id)initWithAwfulPage:(AwfulPage *)page
{
    if((self=[super init])) {
        _page = [page retain];
        
        [self.titles addObject:@"Scroll To Bottom"];
        [self.titles addObject:@"Specific Page"];
        [self.titles addObject:@"Vote"];
        [self.titles addObject:@"Reply"];
        
        if(_page.isBookmarked) {
            [self.titles addObject:@"Remove From Bookmarks"];
        } else {
            [self.titles addObject:@"Add To Bookmarks"];
        }
        
        if(![_page.pages onLastPage]) {
            [self.titles addObject:@"Next Page"];
        }

    }
    return self;
}

-(NSString *)getOverallTitle
{
    return @"Thread Actions";
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{    
    if([self isCancelled:buttonIndex]) {
        return;
    }
    
    if(buttonIndex == AwfulThreadActionScrollToBottom) {
        
        [self.page scrollToBottom];
        
    } else if(buttonIndex == AwfulThreadActionSpecificPage) {
        
        AwfulPageNavController *page_nav = [[AwfulPageNavController alloc] initWithAwfulPage:self.page];
        UIViewController *vc = getRootController();
        [vc presentModalViewController:page_nav animated:YES];
        [page_nav release];
        
    } else if(buttonIndex == AwfulThreadActionVote) {
        
        AwfulVoteActions *vote = [[AwfulVoteActions alloc] initWithAwfulThread:self.page.thread];
        [self.delegate setActions:vote];
        [vote release];
        
    } else if(buttonIndex == AwfulThreadActionReply) {
        
        AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:@""];
        [post_box setThread:self.page.thread];
        UIViewController *vc = getRootController();
        [vc presentModalViewController:post_box animated:YES];
        [post_box release];
        
    } else if(buttonIndex == AwfulThreadActionBookmarks) {
        
        if(self.page.isBookmarked) {
            [self removeBookmark];
        } else {
            [self addBookmark];
        }
        
    } else if(buttonIndex == AwfulThreadActionNextPage) {
        [self.page nextPage];
    }
    
    if(buttonIndex != AwfulThreadActionVote) {
        [self.delegate setActions:nil];
    }
}

-(void)addBookmark
{
    ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
    req.userInfo = [NSDictionary dictionaryWithObject:@"Added to bookmarks." forKey:@"completionMsg"];
    
    [req setPostValue:@"1" forKey:@"json"];
    [req setPostValue:@"add" forKey:@"action"];
    [req setPostValue:self.page.thread.threadID forKey:@"threadid"];
    self.page.isBookmarked = YES;
    
    NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
    [bookmarked_threads addObject:self.page.thread];
    [AwfulUtil saveThreadList:bookmarked_threads forForumId:@"bookmarks"];
    [bookmarked_threads release];
    
    loadRequestAndWait(req);
}

-(void)removeBookmark
{
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
    [bookmarked_threads release];
    
    loadRequestAndWait(req);
}

@end
