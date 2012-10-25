//
//  AwfulThreadActions.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadActions.h"
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPage.h"
#import "AwfulVoteActions.h"
#import <MobileCoreServices/UTCoreTypes.h>

typedef enum {
    AwfulThreadActionCopyURL,
    AwfulThreadActionVote,
    AwfulThreadActionBookmarks,
} AwfulThreadAction;

@interface AwfulThreadActions ()

@property (strong, nonatomic) AwfulThread *thread;

@end

@implementation AwfulThreadActions

-(id)initWithThread:(AwfulThread *)thread
{
    self = [super init];
    if (self) {
        self.thread = thread;
        self.titles = [NSArray arrayWithObjects:
                       @"Copy Thread URL",
                       @"Vote",
                       [thread.isBookmarked boolValue] ? @"Remove From Bookmarks" : @"Add To Bookmarks",
                       nil];
    }
    return self;
}

@synthesize thread = _thread;

-(NSString *)getOverallTitle
{
    return @"Thread Actions";
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == AwfulThreadActionCopyURL) {
        AwfulPage *page = [self getPage];
        NSString *path = nil;
        if(page != nil) {
            path = [NSString stringWithFormat:@"http://forums.somethingawful.com/showthread.php?threadid=%@&pagenumber=%u", self.thread.threadID, page.currentPage];
        } else {
            path = [NSString stringWithFormat:@"http://forums.somethingawful.com/showthread.php?threadid=%@", self.thread.threadID];
        }
        [[UIPasteboard generalPasteboard] setValue:path forPasteboardType:(NSString *)kUTTypeText];
        
    } else if (buttonIndex == AwfulThreadActionVote) {        
        AwfulVoteActions *voteActions = [[AwfulVoteActions alloc] initWithAwfulThread:self.thread];
        AwfulPage *page = [self getPage];
        [page setActions:voteActions];
        [page showActions];
        
    } else if (buttonIndex == AwfulThreadActionBookmarks) {
        if (self.thread.isBookmarkedValue) {
            [[AwfulHTTPClient client] unbookmarkThreadWithID:self.thread.threadID
                                                     andThen:^(NSError *error)
            {
                if (!error) [self updateThreadIsBookmarked];
            }];
        } else {
            [[AwfulHTTPClient client] bookmarkThreadWithID:self.thread.threadID
                                                   andThen:^(NSError *error)
            {
                if (!error) [self updateThreadIsBookmarked];
            }];
        }
    }
}

- (void)updateThreadIsBookmarked
{
    self.thread.isBookmarkedValue = !self.thread.isBookmarkedValue;
    [[AwfulDataStack sharedDataStack] save];
}

-(AwfulPage *)getPage
{
    if([self.viewController isKindOfClass:[AwfulPage class]]) {
        return (AwfulPage *)self.viewController;
    }
    return nil;
}

@end
