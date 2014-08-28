//  AwfulInstapaperLogInController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulInstapaperLogInController.h"
#import "AwfulTextEntryCell.h"
#import "InstapaperAPIClient.h"
#import "Awful-Swift.h"

@interface AwfulInstapaperLogInController () <UITextFieldDelegate>

@property (nonatomic) UIBarButtonItem *cancelButtonItem;

@end

@implementation AwfulInstapaperLogInController
{
    BOOL _loggingIn;
}

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (!self) return nil;
    self.title = @"Log In to Instapaper";
    self.navigationItem.leftBarButtonItem = self.cancelButtonItem;
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    return self;
}

- (UIBarButtonItem *)cancelButtonItem
{
    if (_cancelButtonItem) return _cancelButtonItem;
    _cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                      target:self
                                                                      action:@selector(didTapCancel)];
    return _cancelButtonItem;
}

- (void)didTapCancel
{
    [self.delegate instapaperLogInControllerDidCancel:self];
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[AwfulTextEntryCell class] forCellReuseIdentifier:TextFieldIdentifier];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:ButtonIdentifier];
}

static NSString * const TextFieldIdentifier = @"TextField";
static NSString * const ButtonIdentifier = @"Button";

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.backgroundView = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    AwfulTextEntryCell *cell = (id)[self.tableView cellForRowAtIndexPath:indexPath];
    [cell.textField becomeFirstResponder];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = indexPath.section == 0 ? TextFieldIdentifier : ButtonIdentifier;
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    
    if (identifier == TextFieldIdentifier) {
        AwfulTextEntryCell *textEntryCell = (AwfulTextEntryCell *)cell;
        UITextField *textField = textEntryCell.textField;
        textField.textColor = [UIColor grayColor];
        if (![textField actionsForTarget:self forControlEvent:UIControlEventEditingChanged]) {
            [textField addTarget:self action:@selector(textFieldDidChangeValue:) forControlEvents:UIControlEventEditingChanged];
        }
    } else if (identifier == ButtonIdentifier) {
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (indexPath.section == 0) {
        AwfulTextEntryCell *textEntryCell = (AwfulTextEntryCell *)cell;
        textEntryCell.textField.delegate = self;
        textEntryCell.textField.tag = indexPath.row;
        textEntryCell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textEntryCell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        NSDictionary *placeholderAttributes = @{ NSForegroundColorAttributeName: [UIColor grayColor] };
        if (indexPath.row == 0) {
            textEntryCell.textLabel.text = @"Username";
            textEntryCell.textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Email or username"
                                                                                            attributes:placeholderAttributes];
            textEntryCell.textField.text = self.username;
            textEntryCell.textField.secureTextEntry = NO;
        } else if (indexPath.row == 1) {
            textEntryCell.textLabel.text = @"Password";
            textEntryCell.textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"If you have one"
                                                                                            attributes:placeholderAttributes];
            textEntryCell.textField.text = self.password;
            textEntryCell.textField.secureTextEntry = YES;
        }
    } else if (indexPath.section == 1) {
        cell.textLabel.text = @"Log in";
        cell.textLabel.enabled = !_loggingIn && [self formIsValid];
    }
    
    AwfulTheme *theme = self.theme;
    cell.backgroundColor = theme[@"listBackgroundColor"];
    cell.textLabel.textColor = theme[@"listTextColor"];
    cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = self.theme[@"listSelectedBackgroundColor"];
    
    return cell;
}

- (void)textFieldDidChangeValue:(UITextField *)textField
{
    if (textField.tag == 0) {
        self.username = textField.text;
    } else {
        self.password = textField.text;
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
}

- (BOOL)formIsValid
{
    return self.username.length > 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
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
    _loggingIn = YES;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    self.tableView.userInteractionEnabled = NO;
    __weak __typeof__(self) weakSelf = self;
    [[InstapaperAPIClient client] validateUsername:self.username password:self.password andThen:^(NSError *error) {
        __typeof__(self) self = weakSelf;
        _loggingIn = NO;
        if (error) {
            [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Log In to Instapaper" error:error] animated:YES completion:nil];
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

@end
