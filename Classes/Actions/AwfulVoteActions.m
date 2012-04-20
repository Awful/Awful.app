//
//  AwfulVoteActions.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulVoteActions.h"
#import "AwfulThread.h"
#import "AwfulNetworkEngine.h"
#import "AwfulUtil.h"
#import "AwfulPage.h"

@implementation AwfulVoteActions

@synthesize thread;

-(id)initWithAwfulThread : (AwfulThread *)aThread
{
    if((self=[super init])) {
        self.thread = aThread;
        [self.titles addObjectsFromArray:[NSArray arrayWithObjects:@"5", @"4", @"3", @"2", @"1", nil]];
    }
    return self;
}

-(NSString *)getOverallTitle
{
    return @"Vote!";
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // 0=5, 1=4, 2=3, 3=2, 4=1
    int vote_num = -1;
    switch (buttonIndex) {
        case 0:
            vote_num = 5;
            break;
        case 1:
            vote_num = 4;
            break;
        case 2:
            vote_num = 3;
            break;
        case 3:
            vote_num = 2;
            break;
        case 4:
            vote_num = 1;
            break;
        default:
            break;
    }
    
    if(vote_num != -1) {
        [ApplicationDelegate.awfulNetworkEngine submitVote:vote_num forThread:self.thread onCompletion:^(void) {
            if([self.viewController isKindOfClass:[AwfulPage class]]) {
                AwfulPage *page = (AwfulPage *)self.viewController;
                [page showVoteCompleteMessage];
            }
        } onError:^(NSError *error) {
            [AwfulUtil requestFailed:error];
        }];
    }
}

@end
