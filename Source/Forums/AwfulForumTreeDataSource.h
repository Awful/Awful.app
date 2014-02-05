//  AwfulForumTreeDataSource.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
@protocol AwfulForumTreeDataSourceDelegate;

/**
 * An AwfulForumTreeDataSource represents the category/forum/subforum hierarchy to a table view.
 */
@interface AwfulForumTreeDataSource : NSObject <UITableViewDataSource>

/**
 * Designated initializer for AwfulForumTreeDataSource.
 *
 * @param tableView       The table view provided with data.
 * @param reuseIdentifier A cell reuse identifier for dequeueing cells from the table view.
 */
- (id)initWithTableView:(UITableView *)tableView reuseIdentifier:(NSString *)reuseIdentifier;

@property (readonly, weak, nonatomic) UITableView *tableView;

@property (readonly, copy, nonatomic) NSString *reuseIdentifier;

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
