//
//  AwfulGridViewController.h
//  Awful
//
//  Created by me on 7/31/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFetchedTableViewController.h"

@interface AwfulGridViewController : AwfulFetchedTableViewController {
    int _numColumnsPerRow;
    int _columnWidth;
}


-(UITableViewCell*) gridView:(UITableView *)tableView cellForColumnInRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)configureCell:(UITableViewCell*)cell inRowAtIndexPath:(NSIndexPath *)cellIndexPath;
-(void) gridView:(UITableView *)tableView didSelectCellInRowAtIndexPath:(NSIndexPath *)indexPath;
@end
