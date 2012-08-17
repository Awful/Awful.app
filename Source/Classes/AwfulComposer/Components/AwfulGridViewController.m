//
//  AwfulGridViewController.m
//  Awful
//
//  Created by me on 7/31/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulGridViewController.h"
#import "AwfulImagePickerGridCell.h"

typedef UITableViewCell AwfulGridViewCell;

@interface AwfulGridViewController ()

@end

@implementation AwfulGridViewController

-(void) viewDidLoad {
    [super viewDidLoad];
    _columnWidth = 70;
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //if (!_numIconsPerRow) {
    CGFloat width = self.view.frame.size.width;
    _numColumnsPerRow = width/_columnWidth;
    //}
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    
    if ([sectionInfo numberOfObjects] == 0) return 0;
    int rows = [sectionInfo numberOfObjects]/_numColumnsPerRow + 1;
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)tableIndexPath {
    UITableViewCell *cell;
    cell = [tableView dequeueReusableCellWithIdentifier:@"AwfulGridViewCell"];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:@"AwfulGridViewCell"];
    [self configureCell:cell atIndexPath:tableIndexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell*)gridCell atIndexPath:(NSIndexPath *)tableIndexPath {
    int start = tableIndexPath.row *_numColumnsPerRow;
    gridCell.contentView.backgroundColor = self.tableView.separatorColor;
    gridCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    
    CGFloat width = self.tableView.fsW;
    _numColumnsPerRow = width/_columnWidth;
    
    for(int x = start; x < start + _numColumnsPerRow; x++) {
        //NSLog(@"load index %d", x);
        if (x >= self.fetchedResultsController.fetchedObjects.count) continue;
        
        NSIndexPath* cellIndexPath = [NSIndexPath indexPathForRow:x inSection:tableIndexPath.section];
        UITableViewCell *cell = [self gridView:self.tableView cellForColumnInRowAtIndexPath:cellIndexPath];
        
        [self configureCell:cell inRowAtIndexPath:cellIndexPath];
        cell.frame = CGRectMake((_columnWidth+1) * (x-start), 0, _columnWidth, [self tableView:self.tableView heightForRowAtIndexPath:tableIndexPath] );
        [gridCell.contentView addSubview:cell];
        cell.tag = x;
        
    }
}

-(UITableViewCell*) gridView:(UITableView *)tableView cellForColumnInRowAtIndexPath:(NSIndexPath *)cellIndexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"AwfulImagePickerGridCell"];
    if (!cell)
        cell = [AwfulImagePickerGridCell new];
    
    [self configureCell:cell inRowAtIndexPath:cellIndexPath];

    
    
    return cell;
}

-(void) configureCell:(UITableViewCell *)cell inRowAtIndexPath:(NSIndexPath *)cellIndexPath {
    cell.textLabel.text = [NSString stringWithFormat:@"%i", cellIndexPath.row];
    cell.backgroundColor = [UIColor whiteColor];

    
    UIGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedCell:)];
    [cell addGestureRecognizer:tap];
}

-(void)tappedCell:(UITapGestureRecognizer*)sender {
    UITableViewCell* cell = (UITableViewCell*)sender.view;
    cell.selected = YES;
    NSIndexPath *cellIndexPath = [NSIndexPath indexPathForRow:cell.tag inSection:0];
    [self gridView:self.tableView didSelectCellInRowAtIndexPath:cellIndexPath];
}

-(void) gridView:(UITableView *)tableView didSelectCellInRowAtIndexPath:(NSIndexPath *)indexPath {
    //override me
}


#pragma mark fetchedresultscontroller
//got to override this because there's multiple emotes per row

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    NSIndexPath* calculatedPath = [NSIndexPath indexPathForRow:(indexPath.row/_numColumnsPerRow) inSection:0];
    
    [super controller:controller didChangeObject:anObject atIndexPath:calculatedPath forChangeType:type newIndexPath:calculatedPath];
}


@end
