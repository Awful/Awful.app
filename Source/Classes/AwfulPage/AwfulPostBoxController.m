//
//  AwfulPostBoxController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostBoxController.h"
#import "AwfulPage.h"
#import "AwfulThread.h"
#import "AwfulAppDelegate.h"
#import "AwfulPost.h"
#import "AwfulPage.h"
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

-(void)keyboardWillShow:(NSNotification *)notification
{
    double duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGRect keyboardRect = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardBounds = [self.view convertRect:keyboardRect fromView:nil];
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // using form sheet the keyboard doesn't overlap
        float height = self.view.bounds.size.height;
        float replyBoxHeight = (height - 44 - (height - keyboardBounds.origin.y));
        replyBoxHeight = MAX(350, replyBoxHeight); // someone bugged out the height one time so I'm hacking in a minimum
        self.replyTextView.frame = CGRectMake(5, 44, self.replyTextView.bounds.size.width, replyBoxHeight);
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [UIView animateWithDuration:duration animations:^{
            self.replyTextView.frame = CGRectMake(5, 44, self.replyTextView.bounds.size.width, self.view.bounds.size.height-44-keyboardBounds.size.height);
        }];
    }
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
