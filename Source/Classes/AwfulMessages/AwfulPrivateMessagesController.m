//
//  AwfulPrivateMessagesController.m
//  Awful
//
//  Created by me on 7/20/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessagesController.h"

@interface AwfulPrivateMessagesController ()

@end

@implementation AwfulPrivateMessagesController

-(void) awakeFromNib {
    [self setEntityName:@"AwfulForum"
              predicate:@"category != nil and (children.@count >0 or parentForum.expanded = YES)"
                   sort: [NSArray arrayWithObjects:
                          [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
                          [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES],
                          nil]
             sectionKey:@"category.index"
     ];
}

-(void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    cell.textLabel.text = @"Message Title";
}
@end
