//
//  VoteDelegate.m
//  Awful
//
//  Created by Sean Berry on 11/28/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "VoteDelegate.h"
#import "AwfulNavController.h"
#import "ASIFormDataRequest.h"

@implementation VoteDelegate

@synthesize thread;

-(id)init
{
    thread = nil;
    return self;
}

-(void)dealloc
{
    [thread release];
    [super dealloc];
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
        NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com/threadrate.php"];
        ASIFormDataRequest *form = [ASIFormDataRequest requestWithURL:url];
        [form addPostValue:[[NSNumber numberWithInt:vote_num] stringValue] forKey:@"vote"];
        [form addPostValue:thread.threadID forKey:@"threadid"];
        form.userInfo = [NSDictionary dictionaryWithObject:@"Great Job!" forKey:@"completionMsg"];
        
        AwfulNavController *nav = getnav();
        [nav loadRequestAndWait:form];
    }
}

@end