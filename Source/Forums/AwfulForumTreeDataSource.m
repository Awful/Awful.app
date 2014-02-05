//  AwfulForumTreeDataSource.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumTreeDataSource.h"
#import "AwfulSettings.h"
#import <objc/runtime.h>

@interface AwfulForumTreeDataSource () <NSFetchedResultsControllerDelegate>

/**
 * Does **not** account for the sectionOffset.
 */
- (NSArray *)visibleForumsInSectionAtIndex:(NSInteger)sectionIndex;

/**
 * The number of sections above the first one in the forum tree.
 */
@property (readonly, assign, nonatomic) NSInteger sectionOffset;

@end

@implementation AwfulForumTreeDataSource
{
    NSFetchedResultsController *_fetchedResultsController;
}

- (id)initWithTableView:(UITableView *)tableView reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super init];
    if (!self) return nil;
    _tableView = tableView;
    tableView.dataSource = self;
    _reuseIdentifier = [reuseIdentifier copy];
    return self;
}

- (NSManagedObjectContext *)managedObjectContext
{
    return _fetchedResultsController.managedObjectContext;
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    self.updatesTableView = NO;
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"AwfulForum"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"category != nil"];
    fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
                                      [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES] ];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                    managedObjectContext:managedObjectContext
                                                                      sectionNameKeyPath:@"category.index"
                                                                               cacheName:@"Forum tree data source"];
}

- (void)setUpdatesTableView:(BOOL)updatesTableView
{
    _updatesTableView = updatesTableView;
    if (updatesTableView) {
        _fetchedResultsController.delegate = self;
        NSError *error;
        BOOL ok = [_fetchedResultsController performFetch:&error];
        if (!ok) {
            NSLog(@"%s error performing first fetch of fetched results controller: %@", __PRETTY_FUNCTION__, error);
        }
        [self.tableView reloadData];
    } else {
        _fetchedResultsController.delegate = nil;
    }
}

- (void)setTopDataSource:(id<UITableViewDataSource>)topDataSource
{
    _topDataSource = topDataSource;
    
    // A UITableView interrogates its data source once about which selectors it responds to. This dance causes the table view to interrogate us once more, now that our top data source has changed and we may have different answers.
    self.tableView.dataSource = nil;
    self.tableView.dataSource = self;
}

- (BOOL)forumChildrenExpanded:(AwfulForum *)forum
{
    return [[AwfulSettings settings] childrenExpandedForForumWithID:forum.forumID];
}

- (void)setForum:(AwfulForum *)forum childrenExpanded:(BOOL)childrenExpanded
{
    NSInteger sectionIndex = [_fetchedResultsController indexPathForObject:forum].section;
    NSArray * (^changedIndexPaths)(NSArray *, NSArray *) = ^(NSArray *larger, NSArray *smaller) {
        NSRange rowRange;
        NSUInteger i = [smaller indexOfObject:forum];
        if (i + 1 == smaller.count) {
            rowRange = NSMakeRange(i + 1, larger.count - (i + 1));
        } else {
            id proceedingForum = smaller[i + 1];
            NSUInteger end = [larger indexOfObject:proceedingForum];
            rowRange = NSMakeRange(i + 1, end - (i + 1));
        }
        NSMutableArray *rowPaths = [NSMutableArray new];
        for (NSUInteger i = rowRange.location; i < NSMaxRange(rowRange); i++) {
            [rowPaths addObject:[NSIndexPath indexPathForRow:i inSection:sectionIndex + self.sectionOffset]];
        }
        return rowPaths;
    };
    
    NSArray *previouslyVisible = [self visibleForumsInSectionAtIndex:sectionIndex];
    
    [[AwfulSettings settings] setChildrenExpanded:childrenExpanded forForumWithID:forum.forumID];
    
    NSArray *newlyVisible = [self visibleForumsInSectionAtIndex:sectionIndex];
    
    if (childrenExpanded) {
        [self.tableView insertRowsAtIndexPaths:changedIndexPaths(newlyVisible, previouslyVisible) withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [self.tableView deleteRowsAtIndexPaths:changedIndexPaths(previouslyVisible, newlyVisible) withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)reloadRowWithForum:(AwfulForum *)forum
{
    NSInteger sectionIndex = [_fetchedResultsController indexPathForObject:forum].section;
    NSArray *forums = [self visibleForumsInSectionAtIndex:sectionIndex];
    NSUInteger row = [forums indexOfObject:forum];
    if (row != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:sectionIndex + self.sectionOffset];
        [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (AwfulForum *)forumAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *forums = [self visibleForumsInSectionAtIndex:indexPath.section - self.sectionOffset];
    return forums[indexPath.row];
}

- (NSIndexPath *)indexPathForForum:(AwfulForum *)forum
{
    NSInteger sectionIndex = [_fetchedResultsController indexPathForObject:forum].section;
    NSArray *forums = [self visibleForumsInSectionAtIndex:sectionIndex];
    NSUInteger row = [forums indexOfObject:forum];
    if (row == NSNotFound) return nil;
    return [NSIndexPath indexPathForRow:row inSection:sectionIndex + self.sectionOffset];
}

- (NSString *)categoryNameAtIndex:(NSInteger)index
{
    id <NSFetchedResultsSectionInfo> section = _fetchedResultsController.sections[index - self.sectionOffset];
    AwfulForum *forum = section.objects.firstObject;
    return forum.category.name;
}

- (NSArray *)visibleForumsInSectionAtIndex:(NSInteger)sectionIndex
{
    NSArray *forums = [_fetchedResultsController.sections[sectionIndex] objects];
    NSIndexSet *visibleForumIndexes = [forums indexesOfObjectsPassingTest:^(AwfulForum *forum, NSUInteger i, BOOL *stop) {
        for (;;) {
            forum = forum.parentForum;
            if (!forum) return YES;
            if (![self forumChildrenExpanded:forum]) return NO;
        }
    }];
    return [forums objectsAtIndexes:visibleForumIndexes];
}

- (NSInteger)sectionOffset
{
    return [self.topDataSource numberOfSectionsInTableView:self.tableView];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // Only when the forum list is scraped does the NSFetchedResultsController inform us of changes. That doesn't happen often, so let's just reload everything after it happens.
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _fetchedResultsController.sections.count + self.sectionOffset;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section < self.sectionOffset) {
        return [self.topDataSource tableView:tableView numberOfRowsInSection:section];
    }
    return [self visibleForumsInSectionAtIndex:section - self.sectionOffset].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < self.sectionOffset) {
        return [self.topDataSource tableView:tableView cellForRowAtIndexPath:indexPath];
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:self.reuseIdentifier forIndexPath:indexPath];
    AwfulForum *forum = [self visibleForumsInSectionAtIndex:indexPath.section - self.sectionOffset][indexPath.row];
    [self.delegate configureCell:cell withForum:forum];
    return cell;
}

// The following UITableViewDataSource methods are only implemented for passing along to topDataSource.

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if ([self.topDataSource respondsToSelector:_cmd]) {
        return [self.topDataSource sectionIndexTitlesForTableView:tableView];
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    if ([self.topDataSource respondsToSelector:_cmd]) {
        NSInteger sectionIndex = [self.topDataSource tableView:tableView sectionForSectionIndexTitle:title atIndex:index];
        NSAssert(sectionIndex < self.sectionOffset, @"topDataSource is trying to index into our forum sections");
        return sectionIndex;
    }
    
    // Intentionally explode; we don't handle this and the topDataSource did it wrong.
    return -1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section < self.sectionOffset && [self.topDataSource respondsToSelector:_cmd]) {
        return [self.topDataSource tableView:tableView titleForFooterInSection:section];
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section < self.sectionOffset && [self.topDataSource respondsToSelector:_cmd]) {
        return [self.topDataSource tableView:tableView titleForFooterInSection:section];
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.topDataSource tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < self.sectionOffset) {
        if ([self.topDataSource respondsToSelector:_cmd]) {
            return [self.topDataSource tableView:tableView canEditRowAtIndexPath:indexPath];
        } else {
            return YES;
        }
    }
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < self.sectionOffset) {
        if ([self.topDataSource respondsToSelector:_cmd]) {
            return [self.topDataSource tableView:tableView canMoveRowAtIndexPath:indexPath];
        } else {
            return [self.topDataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)];
        }
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    NSAssert(fromIndexPath.section < self.sectionOffset, @"topDataSource is trying to move our forum");
    NSAssert(toIndexPath.section < self.sectionOffset, @"topDataSource is trying to move into our forums");
    [self.topDataSource tableView:tableView moveRowAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if (sel_isEqual(selector, @selector(tableView:commitEditingStyle:forRowAtIndexPath:))) {
        return [self.topDataSource respondsToSelector:selector];
    } else if (sel_isEqual(selector, @selector(tableView:titleForFooterInSection:))) {
        return [self.topDataSource respondsToSelector:selector];
    } else if (sel_isEqual(selector, @selector(tableView:titleForHeaderInSection:))) {
        return [self.topDataSource respondsToSelector:selector];
    }
    return [super respondsToSelector:selector];
}

@end
