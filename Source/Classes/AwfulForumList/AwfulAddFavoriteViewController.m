//
//  AwfulAddFavoriteViewController.m
//  Awful
//
//  Created by Sean Berry on 4/4/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAddFavoriteViewController.h"
#import "AwfulFavorite.h"
#import "AwfulForum.h"

@implementation AwfulAddFavoriteViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.editing = YES;
    // TODO something nicer than checking the device
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)loadForums
{
    /*
    [super loadForums];
    [self.forumSections makeObjectsPerformSelector:@selector(setAllExpanded)];
    NSInteger i = 0;
    while (i < self.forumSections.count) {
        if ([self.tableView.dataSource tableView:self.tableView numberOfRowsInSection:i] == 0) {
            [self.forumSections removeObjectAtIndex:i];
        } else {
            i += 1;
        }
    }
    [self.tableView reloadData];
     */
}

- (BOOL)canPullToRefresh
{
    return NO;
}

- (IBAction)done
{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - Table View Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}
/*
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self getForumAtIndexPath:indexPath];
    if (forum.favorite)
        return UITableViewCellEditingStyleNone;
    else
        return UITableViewCellEditingStyleInsert;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self getForumAtIndexPath:indexPath];
    return forum.favorite ? nil : indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self addFavoriteForForumAtIndexPath:indexPath];
}

- (void)addFavoriteForForumAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self getForumAtIndexPath:indexPath];
    if (!forum.favorite) {
        NSManagedObjectContext *moc = ApplicationDelegate.managedObjectContext;
        AwfulFavorite *favorite = [AwfulFavorite insertInManagedObjectContext:moc];
        favorite.forum = forum;
        [ApplicationDelegate saveContext];
    }
    AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
    section.forum = nil;
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                          withRowAnimation:UITableViewRowAnimationFade];
    if ([self.tableView.dataSource tableView:self.tableView
                       numberOfRowsInSection:indexPath.section] == 0) {
        [self.forumSections removeObjectAtIndex:indexPath.section];
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                      withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.tableView endUpdates];
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const CellIdentifier = @"ForumCell";   
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    AwfulForumCell *forumCell = (AwfulForumCell *)cell;
    forumCell.forumsList = self;
    forumCell.section = [self getForumSectionAtIndexPath:indexPath];
    [forumCell.arrow removeFromSuperview];
    if ([forumCell.section.forum valueForKey:@"favorite"]) {
        forumCell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        forumCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleInsert) {
        [self addFavoriteForForumAtIndexPath:indexPath];
    }
}
*/
@end
