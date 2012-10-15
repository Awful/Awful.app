//
//  AwfulLoginController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoginController.h"
#import "AwfulAppDelegate.h"
#import "AwfulTextEntryCell.h"

@interface AwfulLoginController () <UITextFieldDelegate>

@property (copy, nonatomic) NSString *username;

@property (copy, nonatomic) NSString *password;

@property (nonatomic) BOOL loggingIn;

@end


@implementation AwfulLoginController

- (id)init
{
    return [super initWithStyle:UITableViewStyleGrouped];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Login";
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithHue:0.604
                                                saturation:0.035
                                                brightness:0.898
                                                     alpha:1];
    UIButton *forgotLink = [UIButton buttonWithType:UIButtonTypeCustom];
    [forgotLink addTarget:self
                   action:@selector(forgotPassword)
         forControlEvents:UIControlEventTouchUpInside];
    [forgotLink setTitle:@"Lost or forgot your password?" forState:UIControlStateNormal];
    [forgotLink setTitleColor:[UIColor colorWithHue:0.584 saturation:0.960 brightness:0.388 alpha:1]
                     forState:UIControlStateNormal];
    forgotLink.titleLabel.font = [UIFont systemFontOfSize:15];
    [forgotLink sizeToFit];
    CGRect frame = forgotLink.frame;
    frame.size.height += 40;
    forgotLink.frame = frame;
    self.tableView.tableFooterView = forgotLink;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    AwfulTextEntryCell *cell = (AwfulTextEntryCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    [cell.textField becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return o != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - UITableView data source and delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
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
            cell = [[AwfulTextEntryCell alloc] initWithReuseIdentifier:TextField];
        } else {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:Button];
            cell.textLabel.textAlignment = UITextAlignmentCenter;
        }
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (indexPath.section == 0) {
        AwfulTextEntryCell *entryCell = (AwfulTextEntryCell *)cell;
        entryCell.textField.delegate = self;
        entryCell.textField.tag = indexPath.row;
        entryCell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        entryCell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        if (indexPath.row == 0) {
            entryCell.textLabel.text = @"User Name";
            entryCell.textField.placeholder = @"Stupid Newbie";
            entryCell.textField.text = self.username;
            entryCell.textField.secureTextEntry = NO;
            entryCell.textField.returnKeyType = [self.password length] > 0 ? UIReturnKeyGo : UIReturnKeyNext;
        } else if (indexPath.row == 1) {
            entryCell.textLabel.text = @"Password";
            entryCell.textField.placeholder = @"Required";
            entryCell.textField.text = self.password;
            entryCell.textField.secureTextEntry = YES;
            entryCell.textField.returnKeyType = [self.username length] > 0 ? UIReturnKeyGo : UIReturnKeyNext;
        }
    } else if (indexPath.section == 1) {
        cell.textLabel.text = @"Login!";
        if (self.loggingIn || ![self formIsValid]) {
            cell.textLabel.textColor = [UIColor grayColor];
        } else {
            cell.textLabel.textColor = [UIColor blackColor];
        }
        if (self.username && self.password) {
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
    }
    
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 1) return nil;
    return [self formIsValid] ? indexPath : nil;
}

- (BOOL)formIsValid
{
    return [self.username length] > 0 && [self.password length] > 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (![self formIsValid]) return;
    [self login];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    NSString *property = textField.tag == 0 ? self.password : self.username;
    textField.returnKeyType = [property length] > 0 ? UIReturnKeyGo : UIReturnKeyNext;
    return YES;
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
    replacementString:(NSString *)string
{
    NSString *value = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (textField.tag == 0) self.username = value;
    else if (textField.tag == 1) self.password = value;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                  withRowAnimation:UITableViewRowAnimationNone];
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (![self formIsValid]) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(textField.tag + 1) % 2
                                                    inSection:0];
        AwfulTextEntryCell *cell = (AwfulTextEntryCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        [cell.textField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
        [self login];
    }
    return YES;
}

#pragma mark - Actions

- (void)login
{
    self.loggingIn = YES;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                  withRowAnimation:UITableViewRowAnimationNone];
    self.tableView.userInteractionEnabled = NO;
    [[AwfulHTTPClient sharedClient] logInAsUsername:self.username
                                       withPassword:self.password
                                            andThen:^(NSError *error)
    {
        if (error) {
            [self.delegate loginController:self didFailToLogInWithError:error];
        } else {
            [self.delegate loginControllerDidLogIn:self];
        }
        self.loggingIn = NO;
        self.tableView.userInteractionEnabled = YES;
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                      withRowAnimation:UITableViewRowAnimationNone];
    }];
}

- (void)forgotPassword
{
    NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com/account.php?action=lostpw"];
    [[UIApplication sharedApplication] openURL:url];
}

@end


BOOL IsLoggedIn()
{
    NSURL *sa = [NSURL URLWithString:@"http://forums.somethingawful.com"];
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:sa];
    return [[cookies valueForKey:@"name"] containsObject:@"bbuserid"];
}
