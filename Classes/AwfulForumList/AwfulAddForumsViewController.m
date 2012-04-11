//
//  AwfulAddForumsViewController.m
//  Awful
//
//  Created by Sean Berry on 4/4/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAddForumsViewController.h"
#import "AwfulForumCell.h"
#import "AwfulForum.h"

@implementation AwfulAddForumsViewController

@synthesize delegate = _delegate;

-(void)loadForums
{
    [super loadForums];
    for(AwfulForumSection *section in self.forumSections) {
        [section setAllExpanded];
    }
    [self.tableView reloadData];
}

-(IBAction)hitDone:(id)sender
{
    [self.delegate loadFavorites];
    [self.delegate.tableView reloadData];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulForum *forum = [self getForumAtIndexPath:indexPath];
    [self toggleFavoriteForForum:forum];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationMiddle];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"ForumCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    AwfulForumCell *forum_cell = (AwfulForumCell *)cell;
    forum_cell.forumsList = self;
    
    AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
    if(section != nil) {
        [forum_cell setSection:section];
        if([section.forum.favorited boolValue]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    [forum_cell.arrow removeFromSuperview];
    return cell;
}

@end
