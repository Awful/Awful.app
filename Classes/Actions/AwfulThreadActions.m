//
//  AwfulThreadActions.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadActions.h"
#import "AwfulThread.h"
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

@interface AwfulThreadActions ()

@property (strong) AwfulThread *thread;

@end

@implementation AwfulThreadActions

-(id)initWithThread:(AwfulThread *)thread
{
    self = [super init];
    if (self) {
        self.thread = thread;
        self.titles = [NSArray arrayWithObjects:@"Vote",
                       [thread.isBookmarked boolValue] ? @"Remove From Bookmarks" : @"Add To Bookmarks",
                       @"Scroll To Bottom",
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
    if (buttonIndex == AwfulThreadActionVote) {
        // TODO show vote selector
    } else if (buttonIndex == AwfulThreadActionBookmarks) {
        CompletionBlock completion = ^{
            self.thread.isBookmarked = [NSNumber numberWithBool:![self.thread.isBookmarked boolValue]];
            NSError *error;
            BOOL success = [[ApplicationDelegate managedObjectContext] save:&error];
            if (!success)
                NSLog(@"error saving isBookmarked: %@", error);
        };
        if ([self.thread.isBookmarked boolValue]) {
            [[ApplicationDelegate awfulNetworkEngine] removeBookmarkedThread:self.thread onCompletion:completion onError:nil];
        } else {
            [[ApplicationDelegate awfulNetworkEngine] addBookmarkedThread:self.thread onCompletion:completion onError:nil];
        }
    } else if (buttonIndex == AwfulThreadActionScrollToBottom) {
        // TODO scroll down
    }
}

@end
