//
//  AwfulThreadComposerViewController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadComposerViewController.h"
#import "AwfulTitleEntryCell.h"

@implementation AwfulThreadComposerViewController

- (id)initWithForum:(AwfulForum *)forum {
    self = [super init];
    _forum = forum;
    
    return self;
}

#pragma mark TableView
//Subclasses may need to add more cells, ie Thread title, thread icon, etc

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}


- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 1) return [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    static NSString* identifier = @"TitleCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[AwfulTitleEntryCell alloc] initWithReuseIdentifier:@"TitleCell"];
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 1) [super configureCell:cell atIndexPath:indexPath];
    else
        ((AwfulTitleEntryCell*)cell).delegate = self;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 1) return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    
    return 50;
}

- (void)chooseThreadTag:(UIImageView *)imageView {
    AwfulEmoticonKeyboardController *picker = [AwfulEmoticonKeyboardController new];
    
    self.pickerPopover = [[UIPopoverController alloc] initWithContentViewController:picker];
    [self.pickerPopover presentPopoverFromRect:imageView.frame inView:self.view permittedArrowDirections:(UIPopoverArrowDirectionAny) animated:YES];
}


@end
