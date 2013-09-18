//  AwfulForumTreeController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulModels.h"
@protocol AwfulForumTreeControllerDelegate;

/**
 * An AwfulForumTreeController manages the hierarchy of category -> forum -> subforum, translating to and from a flat list of visible forums and remembering whether each forum is expanded.
 */
@interface AwfulForumTreeController : NSObject <NSCoding>

/**
 * Returns the number of categories.
 */
- (NSInteger)numberOfCategories;

/**
 * Returns the given AwfulCategory object.
 */
- (AwfulCategory *)categoryAtIndex:(NSInteger)index;

/**
 * Returns the number of visible forums in the given category.
 */
- (NSInteger)numberOfVisibleForumsInCategoryAtIndex:(NSInteger)index;

/**
 * Returns the given AwfulForum object.
 *
 * @param indexPath A two-index path whose first index is the category and whose second index is the forum.
 */
- (AwfulForum *)visibleForumAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns the index path of the given AwfulForum object, or nil if it is not visible.
 */
- (NSIndexPath *)indexPathForVisibleForum:(AwfulForum *)visibleForum;

/**
 * Returns YES if the given forum is expanded, revealing its subforums; or NO otherwise.
 *
 * @param indexPath A two-index path whose first index is the category and whose second index is the forum.
 */
- (BOOL)visibleForumExpandedAtIndexPath:(NSIndexPath *)indexPath;

/**
 * If the visible forum is expanded, it is collapsed; if it's collapsed, it's expanded. The delegate is informed of all resulting changes to the visible forums.
 *
 * @param indexPath A two-index path whose first index is the category and whose second index is the forum.
 */
- (void)toggleVisibleForumExpandedAtIndexPath:(NSIndexPath *)indexPath;

/**
 * A delegate to inform of changes to the forum hierarchy in the backing store.
 */
@property (weak, nonatomic) id <AwfulForumTreeControllerDelegate> delegate;

@end

/**
 * How a category or visible forum changed in the backing store.
 */
typedef NS_ENUM(NSInteger, AwfulForumTreeControllerChangeType)
{
    /**
     * Insert a new section (for the category) or row (for the visible forum).
     */
    AwfulForumTreeControllerChangeTypeInsert,
    
    /**
     * Delete the section (for the category) or row (for the visible forum).
     */
    AwfulForumTreeControllerChangeTypeDelete,
    
    /**
     * Refresh the the section header (for the category) or row (for the visible forum).
     */
    AwfulForumTreeControllerChangeTypeUpdate,
};

/**
 * An AwfulForumTreeControllerDelegate is informed of background changes to categories and forums. It's meant to be used with an API like that of UITableView.
 */
@protocol AwfulForumTreeControllerDelegate <NSObject>

/**
 * The tree controller is about to call some combination of the `-forumTreeController:categoryAtIndex:didChange:` and/or `-forumTreeController:visibleForumAtIndexPath:didChange:` methods one or more times.
 */
- (void)forumTreeControllerWillUpdate:(AwfulForumTreeController *)treeController;

/**
 * A new category has been inserted, or a category has been deleted.
 *
 * @param treeController The tree controller that noticed the change.
 * @param index Which category has changed.
 * @param changeType AwfulForumTreeControllerChangeTypeInsert if a new category was added; or AwfulForumTreeControllerChangeTypeDelete if the category was deleted.
 */
- (void)forumTreeController:(AwfulForumTreeController *)treeController
            categoryAtIndex:(NSInteger)index
                  didChange:(AwfulForumTreeControllerChangeType)changeType;

/**
 * A forum has been inserted, deleted, or updated.
 *
 * @param treeController The tree controller that noticed the change.
 * @param indexPath A two-index path whose first index is the category and whose second index is the forum.
 * @param changeType AwfulForumTreeControllerChangeTypeInsert if a forum was added; AwfulForumTreeControllerChangeTypeDelete if a forum was deleted; or AwfulForumTreeControllerChangeTypeUpdate if the forum's attributes have changed.
 */
- (void)forumTreeController:(AwfulForumTreeController *)treeController
    visibleForumAtIndexPath:(NSIndexPath *)indexPath
                  didChange:(AwfulForumTreeControllerChangeType)changeType;

/**
 * The tree controller has completed calling the `-forumTreeController:categoryAtIndex:didChange:` and/or `-forumTreeController:visibleForumAtIndexPath:didChange:` methods.
 */
- (void)forumTreeControllerDidUpdate:(AwfulForumTreeController *)treeController;

@end
