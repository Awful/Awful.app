//
//  AwfulThreadListActions.m
//  Awful
//
//  Created by Regular Berry on 6/24/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListActions.h"
#import "AwfulThread.h"
#import "AwfulNavigator.h"
#import "AwfulPage.h"
#import "ASIFormDataRequest.h"
#import "AwfulAppDelegate.h"

typedef enum {
    AwfulThreadListActionsTypeFirstPage = 0,
    AwfulThreadListActionsTypeLastPage,
    AwfulThreadListActionsTypeUnread
} AwfulThreadListActionsType;

@implementation AwfulThreadListActions

@synthesize thread;

-(id)initWithAwfulThread : (AwfulThread *)aThread
{
    if((self=[super init])) {
        self.thread = aThread;
        [self.titles addObject:@"First Page"];
        [self.titles addObject:@"Last Page"];
        
        // no mark unread for bookmarks
        UIViewController *vc = getRootController();
        if(vc.modalViewController == nil) {
            [self.titles addObject:@"Mark as Unread"];
        }
    }
    return self;
}

-(NSString *)getOverallTitle
{
    return [NSString stringWithFormat:@"%@", self.thread.title];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == AwfulThreadListActionsTypeFirstPage) {
        
        AwfulPage *thread_detail = [[AwfulPage alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeFirst];
        loadContentVC(thread_detail);
        
    } else if(buttonIndex == AwfulThreadListActionsTypeLastPage) {
        
        AwfulPage *thread_detail = [[AwfulPage alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeLast];
        loadContentVC(thread_detail);
        
    } else if(buttonIndex == AwfulThreadListActionsTypeUnread && [self.titles count] > 2) {
        NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com/showthread.php"];
        ASIFormDataRequest *form = [ASIFormDataRequest requestWithURL:url];
        [form setPostValue:self.thread.threadID forKey:@"threadid"];
        [form setPostValue:@"resetseen" forKey:@"action"];
        [form setPostValue:@"1" forKey:@"json"];
        form.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Unread", @"completionMsg", @"1", @"refresh", nil];
        loadRequestAndWait(form);
    }
    [self.navigator setActions:nil];
}

@end