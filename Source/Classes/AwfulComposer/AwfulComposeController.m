//
//  AwfulComposeController.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeController.h"
#import "AwfulPostComposerView.h"

@interface AwfulComposeController ()

@end

@implementation AwfulComposeController
@synthesize composerView = _composerView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    cellTypes = [NSArray arrayWithObjects:
                  @"AwfulCurrentUserCell",
                  @"AwfulTextFieldCell",
                  @"AwfulTextFieldCell",
                  @"AwfulPostIconCell",
                  @"AwfulTextFieldCell",
                  @"AwfulPostOptionsCell",
                  @"AwfulImageAttachmentCell",
                  nil];
}

-(int) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(int) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return cellTypes.count;
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = [cellTypes objectAtIndex:indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell)
        cell = [[NSClassFromString(cellIdentifier) alloc] initWithStyle:(UITableViewCellStyleValue1) reuseIdentifier:cellIdentifier];
    
    cell.textLabel.text = cellIdentifier;
    
    return cell;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 4)
        return 300;
    return 44;
}


@end
