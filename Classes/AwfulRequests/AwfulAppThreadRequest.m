//
//  AwfulAppThreadRequest.m
//  Awful
//
//  Created by Regular Berry on 6/28/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAppThreadRequest.h"
#import "AwfulPage.h"
#import "AwfulThread.h"
#import "AwfulNavigator.h"

@implementation AwfulAppThreadRequest

-(id)initCustom
{
    if((self=[super initWithURL:[NSURL URLWithString:@"http://www.seaneseor.com/awful/awfulappthreadid.txt"]])) {
        
    }
    return self;
}

-(void)requestFinished
{
    [super requestFinished];
    NSString *threadid = [self responseString];
    if(threadid != nil) {
        AwfulThread *thread = [[AwfulThread alloc] init];
        thread.title = @"Awful iPhone App";
        thread.threadID = threadid;
        AwfulPage *page;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            page = [[AwfulPageIpad alloc] initWithAwfulThread:thread startAt:AwfulPageDestinationTypeFirst];
        } else {
            page = [[AwfulPage alloc] initWithAwfulThread:thread startAt:AwfulPageDestinationTypeFirst];
        }
        
        loadContentVC(page);
        
        AwfulNavigator *nav = getNavigator();
        [nav.navigationController popViewControllerAnimated:YES];
    }
}

@end
