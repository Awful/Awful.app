//
//  AwfulFetchedTableViewController.h
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"

@interface AwfulFetchedTableViewController : AwfulTableViewController

- (void)setEntityType:(Class)entity
            predicate:(NSPredicate *)predicate
      sortDescriptors:(NSArray *)sortDescriptors
   sectionNameKeyPath:(NSString*)sectionNameKeyPath;

@end
