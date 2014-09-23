//  AwfulForumTreeDataSource.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@protocol AwfulForumTreeDataSourceDelegate;

/**
 * An AwfulForumTreeDataSource represents the category/forum/subforum hierarchy to a table view.
 */
@interface AwfulForumTreeDataSource : NSObject <UITableViewDataSource>

/**
 * @param reuseIdentifier A cell reuse identifier for dequeueing cells from the table view.
 */
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier NS_DESIGNATED_INITIALIZER;

@property (readonly, copy, nonatomic) NSString *reuseIdentifier;

/**
 * The table view presumably sourcing data from the data source. Populated by setting the forum tree data source as the table view's dataSource.
 */
@property (readonly, weak, nonatomic) UITableView *tableView;

/**
 * The managed object context to use for fetching categories and forums. Setting the managedObjectContext pauses the AwfulForumTreeDataSource.
 */
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

/**
 * YES if the AwfulForumTreeDataSource updates its table view as updates come in, otherwise NO (the default). Consider setting updatesTableView to YES in -viewWillAppear: and to NO in -viewDidDisappear:.
 */
@property (assign, nonatomic) BOOL updatesTableView;

/**
 * If non-nil, a data source whose sections are inserted at the top of the table. The topDataSource is only called for methods implemented by AwfulForumTreeDataSource, which does not include several optional methods.
 */
@property (weak, nonatomic) id <UITableViewDataSource> topDataSource;

/**
 * Returns YES if the forum's children are expanded, otherwise NO.
 */
- (BOOL)forumChildrenExpanded:(AwfulForum *)forum;

/**
 * Expands or collapses a forum's children.
 */
- (void)setForum:(AwfulForum *)forum childrenExpanded:(BOOL)childrenExpanded;

- (void)reloadRowWithForum:(AwfulForum *)forum;

- (AwfulForum *)forumAtIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForForum:(AwfulForum *)forum;

- (NSString *)categoryNameAtIndex:(NSInteger)index;

@property (weak, nonatomic) id <AwfulForumTreeDataSourceDelegate> delegate;

@end

@protocol AwfulForumTreeDataSourceDelegate <NSObject>

/**
 * Asks the delegate to configure a UITableViewCell to represent a forum.
 *
 * @param cell A UITableViewCell (or subclass), typed as `id` so explicit casting is unnecessary.
 */
- (void)configureCell:(id)cell withForum:(AwfulForum *)forum;

@end
