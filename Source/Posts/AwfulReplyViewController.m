//
//  AwfulReplyViewController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulPage.h"
#import "AwfulAppDelegate.h"
#import "MBProgressHUD.h"
#import "ButtonSegmentedControl.h"

@interface AwfulReplyViewController () <UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UIBarButtonItem *sendButton;
@property (nonatomic, strong) IBOutlet UITextView *replyTextView;
@property (nonatomic, strong) IBOutlet ButtonSegmentedControl *segmentedControl;

@property (nonatomic, strong) NSOperation *networkOperation;

@end

@implementation AwfulReplyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.segmentedControl.action = @selector(tappedSegment:);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    self.replyTextView.text = self.startingText;
    [self.replyTextView becomeFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.sendButton.title = self.post ? @"Save" : @"Reply";
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (IBAction)tappedSegment:(id)sender
{
    NSInteger index = self.segmentedControl.selectedSegmentIndex;
    [self hitTextBarButtonItem:[self.segmentedControl titleForSegmentAtIndex:index]];
}

- (void)keyboardWillShow:(NSNotification *)note
{
    double duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGRect keyboardRect = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardBounds = [self.view convertRect:keyboardRect fromView:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // using form sheet the keyboard doesn't overlap
        CGFloat height = self.view.bounds.size.height;
        CGFloat replyBoxHeight = height - 44 - (height - keyboardBounds.origin.y);
        replyBoxHeight = MAX(350, replyBoxHeight); // someone bugged out the height one time so I'm hacking in a minimum
        self.replyTextView.frame = CGRectMake(5, 44, self.replyTextView.bounds.size.width, replyBoxHeight);
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [UIView animateWithDuration:duration animations:^{
            self.replyTextView.frame = (CGRect){
                .origin = { 5, 44 },
                .size.width = self.replyTextView.bounds.size.width,
                .size.height = self.view.bounds.size.height - 44 - keyboardBounds.size.height
            };
        }];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != 1) return;

    [self.networkOperation cancel];
    
    if (self.thread) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
        hud.labelText = @"Replying…";
        self.networkOperation = [[AwfulHTTPClient sharedClient] replyToThread:self.thread
                                                                     withText:self.replyTextView.text
                                                                 onCompletion:^
        {
            [MBProgressHUD hideHUDForView:self.view animated:NO];
            [self.presentingViewController dismissModalViewControllerAnimated:YES];
            [self.page refresh];
        } onError:^(NSError *error)
        {
            [MBProgressHUD hideHUDForView:self.view animated:NO];
            [ApplicationDelegate requestFailed:error];
        }];
    } else if (self.post) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
        hud.labelText = @"Editing…";
        self.networkOperation = [[AwfulHTTPClient sharedClient] editPost:self.post
                                                            withContents:self.replyTextView.text
                                                            onCompletion:^
        {
            [MBProgressHUD hideHUDForView:self.view animated:NO];
            [self.presentingViewController dismissModalViewControllerAnimated:YES];
            [self.page hardRefresh];
        } onError:^(NSError *error)
        {
            [MBProgressHUD hideHUDForView:self.view animated:NO];
            [ApplicationDelegate requestFailed:error];
        }];
    }
    [self.replyTextView resignFirstResponder];
}

- (IBAction)hideReply
{
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    [self.presentingViewController dismissModalViewControllerAnimated:YES];
}

- (IBAction)hitSend
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Incoming Forums Superstar"
                                                    message:@"Does my reply offer any significant advice or help contribute to the conversation in any fashion?"
                                                   delegate:self
                                          cancelButtonTitle:@"Nope"
                                          otherButtonTitles:self.sendButton.title, nil];
    alert.delegate = self;
    [alert show];
}

- (void)hitTextBarButtonItem:(NSString *)str
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
