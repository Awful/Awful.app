//
//  AwfulInstapaperLogInController.m
//  Awful
//
//  Created by Nolan Waite on 2013-05-09.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulInstapaperLogInController.h"
#import "AwfulAlertView.h"
#import "AwfulTextEntryCell.h"
#import "AwfulTheme.h"
#import "AwfulThemingViewController.h"
#import "InstapaperAPIClient.h"

@interface AwfulInstapaperLogInController () <AwfulThemingViewController, UITextFieldDelegate>

@property (nonatomic) UIBarButtonItem *cancelButtonItem;
@property (nonatomic) BOOL loggingIn;

@end

@implementation AwfulInstapaperLogInController

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStyleGrouped])) return nil;
    self.title = @"Log In to Instapaper";
    self.navigationItem.leftBarButtonItem = self.cancelButtonItem;
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    return self;
}

- (UIBarButtonItem *)cancelButtonItem
{
    if (_cancelButtonItem) return _cancelButtonItem;
    _cancelButtonItem = [[UIBarButtonItem alloc]
                         initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                         target:self action:@selector(didTapCancel)];
    return _cancelButtonItem;
}

- (void)didTapCancel
{
    [self.delegate instapaperLogInControllerDidCancel:self];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.backgroundView = nil;
    [self retheme];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    AwfulTextEntryCell *cell = (id)[self.tableView cellForRowAtIndexPath:indexPath];
    [cell.textField becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else {
        return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
    }
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section == 0 ? 2 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const TextField = @"TextField";
    static NSString * const Button = @"Button";
    NSString *identifier = indexPath.section == 0 ? TextField : Button;
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        if (identifier == TextField) {
            cell = [[AwfulTextEntryCell alloc] initWithReuseIdentifier:identifier];
            UITextField *textField = [(AwfulTextEntryCell *)cell textField];
            [textField addTarget:self action:@selector(textFieldDidChangeValue:)
                forControlEvents:UIControlEventEditingChanged];
        } else {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:Button];
            cell.textLabel.textAlignment = UITextAlignmentCenter;
        }
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (indexPath.section == 0) {
        AwfulTextEntryCell *entryCell = (id)cell;
        entryCell.textField.delegate = self;
        entryCell.textField.tag = indexPath.row;
        entryCell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        entryCell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        if (indexPath.row == 0) {
            entryCell.textLabel.text = @"Username";
            entryCell.textField.placeholder = @"Email or username";
            entryCell.textField.text = self.username;
            entryCell.textField.secureTextEntry = NO;
        } else if (indexPath.row == 1) {
            entryCell.textLabel.text = @"Password";
            entryCell.textField.placeholder = @"If you have one";
            entryCell.textField.text = self.password;
            entryCell.textField.secureTextEntry = YES;
        }
    } else if (indexPath.section == 1) {
        cell.textLabel.text = @"Log in";
        if (self.loggingIn || ![self formIsValid]) {
            cell.textLabel.textColor = [UIColor grayColor];
        } else {
            cell.textLabel.textColor = [UIColor blackColor];
        }
    }
    return cell;
}

- (void)textFieldDidChangeValue:(UITextField *)textField
{
    if (textField.tag == 0) {
        self.username = textField.text;
    } else {
        self.password = textField.text;
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                  withRowAnimation:UITableViewRowAnimationNone];
}

- (BOOL)formIsValid
{
    return [self.username length] > 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == 1 && [self formIsValid] ? indexPath : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self formIsValid]) {
        [self login];
    }
}

- (void)login
{
    self.loggingIn = YES;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                  withRowAnimation:UITableViewRowAnimationNone];
    self.tableView.userInteractionEnabled = NO;
    [[InstapaperAPIClient client] validateUsername:self.username
                                          password:self.password
                                           andThen:^(NSError *error)
    {
        self.loggingIn = NO;
        if (error) {
            [AwfulAlertView showWithTitle:@"Could Not Log In to Instapaper"
                                    error:error
                              buttonTitle:@"OK"];
        } else {
            [self.delegate instapaperLogInControllerDidSucceed:self];
        }
        self.tableView.userInteractionEnabled = YES;
        [self.tableView reloadData];
    }];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField.tag == 0) {
        textField.returnKeyType = ([self.password length] > 0 ? UIReturnKeyGo : UIReturnKeyNext);
    } else {
        textField.returnKeyType = ([self.username length] > 0 ? UIReturnKeyGo : UIReturnKeyNext);
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([self formIsValid] && ([self.password length] > 0 || textField.tag == 1)) {
        [textField resignFirstResponder];
        [self login];
    } else {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(textField.tag + 1) % 2 inSection:0];
        AwfulTextEntryCell *cell = (id)[self.tableView cellForRowAtIndexPath:indexPath];
        [cell.textField becomeFirstResponder];
    }
    return YES;
}

#pragma mark - AwfulThemingViewController

- (void)retheme
{
    self.tableView.backgroundColor = [AwfulTheme currentTheme].loginViewBackgroundColor;
}

@end
