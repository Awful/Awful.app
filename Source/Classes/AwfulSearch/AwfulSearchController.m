//
//  AwfulSearchController.m
//  Awful
//
//  Created by me on 7/20/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSearchController.h"

@implementation AwfulSearchController

- (void)awakeFromNib
{
    [self setEntityType:[AwfulThread class]
              predicate:nil
        sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]]
     sectionNameKeyPath:nil];
}

- (void) configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath
{
    cell.textLabel.text = @"aaaaa";
}

@end
