//
//  AwfulPostBoxController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostBoxController.h"
#import "AwfulPage.h"
#import "AwfulAppDelegate.h"
#import "MBProgressHUD.h"
#import "ButtonSegmentedControl.h"

@implementation AwfulPostBoxController

@synthesize replyTextView = _replyTextView;
@synthesize sendButton = _sendButton;
@synthesize thread = _thread;
@synthesize post = _post;
@synthesize startingText = _startingText;
@synthesize networkOperation = _networkOperation;
@synthesize page = _page;
@synthesize segmentedControl = _segmentedControl;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.segmentedControl.action = @selector(tappedSegment:);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    self.replyTextView.text = self.startingText;
    [self.replyTextView becomeFirstResponder];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.sendButton.title = self.post ? @"Save" : @"Reply";
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.sendButton = nil;
    self.replyTextView = nil;
    self.segmentedControl = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

-(void)tappedSegment:(id)sender
{
    NSString *str = [self.segmentedControl titleForSegmentAtIndex:self.segmentedControl.selectedSegmentIndex];
    [self hitTextBarButtonItem:str];
}

- (void)keyboardDidShow:(NSNotification *)note
{
    CGRect keyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect relativeKeyboardFrame = [self.replyTextView convertRect:keyboardFrame fromView:nil];
    CGRect overlap = CGRectIntersection(relativeKeyboardFrame, self.replyTextView.bounds);
    // The 2 isn't strictly necessary, I just like a little cushion between the cursor and keyboard.
    UIEdgeInsets insets = (UIEdgeInsets){ .bottom = overlap.size.height + 2 };
    self.replyTextView.contentInset = insets;
    self.replyTextView.scrollIndicatorInsets = insets;
    [self.replyTextView scrollRangeToVisible:self.replyTextView.selectedRange];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    self.replyTextView.contentInset = UIEdgeInsetsZero;
    self.replyTextView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1) {
        [self.networkOperation cancel];
        if(self.thread != nil) {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
            hud.labelText = @"Replying...";
            self.networkOperation = [[AwfulHTTPClient sharedClient] replyToThread:self.thread withText:self.replyTextView.text onCompletion:^{
                [MBProgressHUD hideHUDForView:self.view animated:NO];
                [self.presentingViewController dismissModalViewControllerAnimated:YES];
                [self.page refresh];
            } onError:^(NSError *error) {
                [MBProgressHUD hideHUDForView:self.view animated:NO];
                [ApplicationDelegate requestFailed:error];
            }];
        } else if(self.post != nil) {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
            hud.labelText = @"Editing...";
            self.networkOperation = [[AwfulHTTPClient sharedClient] editPost:self.post withContents:self.replyTextView.text onCompletion:^{
                [MBProgressHUD hideHUDForView:self.view animated:NO];
                [self.presentingViewController dismissModalViewControllerAnimated:YES];
                [self.page hardRefresh];
            } onError:^(NSError *error) {
                [MBProgressHUD hideHUDForView:self.view animated:NO];
                [ApplicationDelegate requestFailed:error];
            }];
        }
            
        [self.replyTextView resignFirstResponder];
    }
}

-(void)hideReply
{
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    [self.presentingViewController dismissModalViewControllerAnimated:YES];
}

-(void)hitSend
{
    NSString *send_title = self.sendButton.title;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Are you sure?" message:[NSString stringWithFormat:@"Confirm you want to %@.", send_title] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:send_title, nil];
    alert.delegate = self;
    [alert show];
}

-(IBAction)hitTextBarButtonItem : (NSString *)str
{
    NSMutableString *replyString = [[NSMutableString alloc] initWithString:[self.replyTextView text]];
    
    NSRange cursorPosition = [self.replyTextView selectedRange];
    if(cursorPosition.length == 0) {
        [replyString insertString:str atIndex:cursorPosition.location];
    } else  {
        [replyString replaceCharactersInRange:cursorPosition withString:str];
    }
    self.replyTextView.text = replyString;
    self.replyTextView.selectedRange = NSMakeRange(cursorPosition.location+1, cursorPosition.length);
    self.segmentedControl.selectedSegmentIndex = -1;
}

@end
