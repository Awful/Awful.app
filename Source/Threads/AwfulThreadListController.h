//
//  AwfulThreadListController.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFetchedTableViewController.h"
@class AwfulForum;

@interface AwfulThreadListController : AwfulFetchedTableViewController

// Designated initializer.
- (id)init;

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, assign) NSInteger currentPage;

- (void)loadPageNum:(NSUInteger)pageNum;

- (void)updateThreadTag:(NSString *)threadTagName forCellAtIndexPath:(NSIndexPath *)indexPath;
@end
