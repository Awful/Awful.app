//
//  AwfulAddFavoriteViewController.m
//  Awful
//
//  Created by Sean Berry on 4/4/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAddFavoriteViewController.h"
#import "AwfulForumsListControllerSubclass.h"
#import "AwfulForumCell.h"
#import "AwfulForum.h"

@implementation AwfulAddFavoriteViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.editing = YES;
}

- (NSPredicate *)forumsPredicate
{
    return [NSPredicate predicateWithFormat:@"favorite == nil"];
}

- (void)loadForums
{
    [super loadForums];
    [self.forumSections makeObjectsPerformSelector:@selector(setAllExpanded)];
    [self.tableView reloadData];
}

- (void)finishedRefreshing
{
    [super finishedRefreshing];
    [self.forumSections makeObjectsPerformSelector:@selector(setAllExpanded)];
    [self.tableView reloadData];
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

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleInsert;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self getForumAtIndexPath:indexPath];
    if (![forum valueForKey:@"favorite"]) {
        NSManagedObject *favorite = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" 
                                                                  inManagedObjectContext:ApplicationDelegate.managedObjectContext];
        [favorite setValue:forum forKey:@"forum"];
        [ApplicationDelegate saveContext];
    }
    AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
    section.forum = nil;
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                     withRowAnimation:UITableViewRowAnimationFade];
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
    return cell;
}

@end
