//
//  AwfulPMComposerViewController.m
//  Awful
//
//  Created by me on 2/10/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPMComposerViewController.h"
#import "AwfulTitleEntryCell.h"
#import "AwfulTextEntryCell.h"

@interface AwfulPMComposerViewController ()

@end

@implementation AwfulPMComposerViewController


- (id)initWithDraft:(AwfulPrivateMessage *)draft {
    self = [super init];
    //_forum = forum;
    self.navigationItem.title = @"New PM";
    return self;
}

- (id)initWithReplyToPM:(AwfulPrivateMessage *)msg {
    self = [super init];
    //_forum = forum;
    self.navigationItem.title = @"Reply";
    return self;
}

#pragma mark TableView
//Subclasses may need to add more cells, ie Thread title, thread icon, etc

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}


- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 2) return [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    UITableViewCell *cell;
    if (indexPath.row == 0) {
        static NSString* identifier = @"RecipientCell";
        cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) cell = [[AwfulTextEntryCell alloc] initWithReuseIdentifier:identifier];
    }
    else {
        static NSString* identifier = @"TitleCell";
        cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) cell = [[AwfulTitleEntryCell alloc] initWithReuseIdentifier:identifier];
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 2) {
        [super configureCell:cell atIndexPath:indexPath];
        return;
    }

    AwfulTextEntryCell *textEntryCell = (AwfulTextEntryCell*)cell;
    textEntryCell.textField.tag = indexPath.row;
    textEntryCell.textField.returnKeyType = UIReturnKeyNext;
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Send to:";
        textEntryCell.textField.placeholder = @"Recipient";
        textEntryCell.textField.delegate = self;
    }
    else if (indexPath.row == 1) {
        ((AwfulTitleEntryCell*)cell).delegate = self;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 2) return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    
    return 50;
}

#pragma mark text/title delegate
- (void)chooseThreadTag:(UIImageView *)imageView {
    #warning fixme, replace with a thread tag picker
    AwfulEmoticonKeyboardController *picker = [AwfulEmoticonKeyboardController new];
    
    self.pickerPopover = [[UIPopoverController alloc] initWithContentViewController:picker];
    [self.pickerPopover presentPopoverFromRect:imageView.frame inView:self.view permittedArrowDirections:(UIPopoverArrowDirectionAny) animated:YES];
}

#pragma mark textfield delegate
- (void)textFieldDidEndEditing:(UITextField *)textField {
    int row = textField.tag + 1;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    
    [[self.tableView cellForRowAtIndexPath:indexPath] becomeFirstResponder];
}

@end
