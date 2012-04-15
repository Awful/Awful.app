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
#import "AwfulNetworkEngine.h"
#import "AwfulUtil.h"
#import "AwfulVoteActions.h"

typedef enum {
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
    if (buttonIndex == AwfulThreadActionVote) {
        // TODO show vote selector
    } else if (buttonIndex == AwfulThreadActionBookmarks) {
        CompletionBlock completion = ^{
            // TODO Right now, changes to bookmarks aren't persisted, presumably because we're
            // changing how that persistence happens. If AwfulThread implements NSCoding once more,
            // uncomment this; otherwise, delete it and do the needful.
            /*
            NSMutableArray *bookmarks = [AwfulUtil newThreadListForForumId:@"bookmarks"];
            if (self.page.isBookmarked) {
                NSPredicate *filter = [NSPredicate predicateWithFormat:@"threadID != %@",
                                       self.page.thread.threadID];
                [bookmarks filterUsingPredicate:filter];
            } else {
                [bookmarks addObject:self.page.thread];
            }
            [AwfulUtil saveThreadList:bookmarks forForumId:@"bookmarks"];
             */
            self.page.isBookmarked = !self.page.isBookmarked;
        };
        if (self.page.isBookmarked) {
            [[ApplicationDelegate awfulNetworkEngine] removeBookmarkedThread:self.page.thread onCompletion:completion onError:nil];
        } else {
            [[ApplicationDelegate awfulNetworkEngine] addBookmarkedThread:self.page.thread onCompletion:completion onError:nil];
        }
    } else if (buttonIndex == AwfulThreadActionScrollToBottom) {
        // TODO scroll down
    }
}

@end
