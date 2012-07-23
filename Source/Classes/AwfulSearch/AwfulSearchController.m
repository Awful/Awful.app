//
//  AwfulSearchController.m
//  Awful
//
//  Created by me on 7/20/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSearchController.h"

@interface AwfulSearchController ()

@end

@implementation AwfulSearchController

-(void) awakeFromNib {
    [self setEntityName:@"AwfulThread"
              predicate:nil
                   sort: [NSArray arrayWithObjects:
                          [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO],
                          nil]
             sectionKey:nil
     ];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

-(void) configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath {
    cell.textLabel.text = @"aaaaa";
}



@end
