//
//  AwfulThreadListIpad.m
//  Awful
//
//  Created by Sean Berry on 3/13/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListIpad.h"
#import "AwfulPageIpad.h"
#import "AwfulSplitViewController.h"
#import "AwfulPageCount.h"

@implementation AwfulThreadListIpad

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if(indexPath.row == [self.awfulThreads count]) {
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    } else {
        [self.networkOperation cancel];
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        AwfulPageIpad *page = [[ApplicationDelegate.splitController viewControllers] objectAtIndex:1];
        page.thread = thread;
        [page refresh];
    }
}

@end