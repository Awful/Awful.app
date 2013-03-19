//
//  AwfulThreadListController.h
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulFetchedTableViewController.h"
@class AwfulForum;

@interface AwfulThreadListController : AwfulFetchedTableViewController

// Designated initializer.
- (id)init;

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, assign) NSInteger currentPage;

- (void)loadPageNum:(NSUInteger)pageNum;

@end
