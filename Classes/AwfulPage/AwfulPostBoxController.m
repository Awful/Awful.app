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
#import "AwfulUtil.h"
#import "AwfulPage.h"
#import "MBProgressHUD.h"
#import "AwfulNetworkEngine.h"
#import "ButtonSegmentedControl.h"
#import "AwfulPostComposerView.h"
#import "AwfulEmote.h"

@implementation AwfulPostBoxController

@synthesize replyTextView = _replyTextView;
@synthesize replyWebView = _replyWebView;
@synthesize sendButton = _sendButton;
@synthesize thread = _thread;
@synthesize post = _post;
@synthesize startingText = _startingText;
@synthesize networkOperation = _networkOperation;
@synthesize page = _page;
@synthesize segmentedControl = _segmentedControl;
@synthesize popoverController = __popoverController;

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.segmentedControl.action = @selector(tappedSegment:);
    
    if(self.post != nil) {
        [self.sendButton setTitle:@"Edit"];
    } else if(self.thread != nil) {
        [self.sendButton setTitle:@"Reply"];
    }
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    
    [nc addObserver:self selector:@selector(didChooseEmote:) name:NOTIFY_EMOTE_SELECTED object:nil];
    
    [self setMenuControllerItems];
    

    //[self.replyTextView becomeFirstResponder];
    
}

-(void) setMenuControllerItems {
    NSArray *array = [NSArray arrayWithObjects:
                      [[UIMenuItem alloc] initWithTitle:@"Bold" action:@selector(bold)],
                      [[UIMenuItem alloc] initWithTitle:@"Italic" action:@selector(italic)],
                      [[UIMenuItem alloc] initWithTitle:@"Underline" action:@selector(underline)],
                      
                      nil];
    [[UIMenuController sharedMenuController] setMenuItems:array];
}

- (void)bold {
    [self.replyWebView bold];
}

- (void)italic {
    [self.replyWebView italic];
}

- (void)underline {
    [self.replyWebView underline];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.sendButton.title = self.post ? @"Save" : @"Reply";
    [self.replyWebView becomeFirstResponder];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.sendButton = nil;
    self.replyTextView = nil;
    //self.replyWebView = nil;
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
    switch (self.segmentedControl.selectedSegmentIndex) {
        case PostEditorSegmentEmote:
            
            break;
            
        case PostEditorSegmentImage:
            break;
            
        case PostEditorSegmentFormat:
            [self presentFormatActionSheet];
            
        default:
            break;
    }
    //NSString *str = [self.segmentedControl titleForSegmentAtIndex:self.segmentedControl.selectedSegmentIndex];
    //[self hitTextBarButtonItem:str];
    //if (self.segmentedControl.selectedSegmentIndex == 0) {
        //[self performSegueWithIdentifier: @"emotePopOver" sender: self];
        /*
        pop = [[UIPopoverController alloc] initWithContentViewController:[UIViewController new]];
                                    
        [pop presentPopoverFromRect:[[self.segmentedControl.subviews objectAtIndex:0] frame]
                             inView:self.view 
           permittedArrowDirections:(UIPopoverArrowDirectionUp) 
                           animated:YES];
        */
    //}
    
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
        self.replyWebView.frame = CGRectMake(5, 44, self.replyWebView.bounds.size.width, replyBoxHeight);
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [UIView animateWithDuration:duration animations:^{
            self.replyWebView.frame = CGRectMake(5, 44, self.replyWebView.bounds.size.width, self.view.bounds.size.height-44-keyboardBounds.size.height);
        }];
    }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSLog(@"Posting: %@", self.replyWebView.bbcode);
    
    /*
    if(buttonIndex == 1) {
        [self.networkOperation cancel];
        if(self.thread != nil) {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
            hud.labelText = @"Replying...";
            self.networkOperation = [[ApplicationDelegate awfulNetworkEngine] replyToThread:self.thread withText:self.replyWebView.text onCompletion:^{
                [MBProgressHUD hideHUDForView:self.view animated:NO];
                [self.presentingViewController dismissModalViewControllerAnimated:YES];
                [self.page refresh];
            } onError:^(NSError *error) {
                [MBProgressHUD hideHUDForView:self.view animated:NO];
                [AwfulUtil requestFailed:error];
            }];
        } else if(self.post != nil) {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
            hud.labelText = @"Editing...";
            self.networkOperation = [[ApplicationDelegate awfulNetworkEngine] editPost:self.post withContents:self.replyTextView.text onCompletion:^{
                [MBProgressHUD hideHUDForView:self.view animated:NO];
                [self.presentingViewController dismissModalViewControllerAnimated:YES];
                [self.page hardRefresh];
            } onError:^(NSError *error) {
                [MBProgressHUD hideHUDForView:self.view animated:NO];
                [AwfulUtil requestFailed:error];
            }];
        }
            
        [self.replyTextView resignFirstResponder];
    }
     */
}

-(void)hideReply
{
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    [self.presentingViewController dismissModalViewControllerAnimated:YES];
}

-(void)hitSend
{
    NSLog(@"post: %@", self.replyWebView.bbcode);
    /*
    NSString *send_title = self.sendButton.title;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Are you sure?" message:[NSString stringWithFormat:@"Confirm you want to %@.", send_title] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:send_title, nil];
    alert.delegate = self;
    [alert show];
     */
}

-(IBAction)hitTextBarButtonItem : (NSString *)str
{
    /*
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
*/
}

-(void) didChooseEmote:(NSNotification*)emoteSelectedNotification {
    //close popover on ipad or dismiss modal on iphone
    if (self.popoverController && self.popoverController.isPopoverVisible)
        [self.popoverController dismissPopoverAnimated:YES];
    
    else {
        [self dismissModalViewControllerAnimated:YES];
    }
    
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"emoteChooserPopover"]) 
        self.popoverController = [(UIStoryboardPopoverSegue*)segue popoverController];
    else
        [self.popoverController dismissPopoverAnimated:YES];
    
    
}

-(void) presentFormatActionSheet {
        UIActionSheet *action = [[UIActionSheet alloc] initWithTitle:@"Formatting" 
                                                            delegate:self 
                                                   cancelButtonTitle:@"Cancel"
                                              destructiveButtonTitle:nil 
                                                   otherButtonTitles:@"Bold",
                                 @"Italic", 
                                 @"Underline", 
                                 @"Strikethrough", 
                                 @"Super", 
                                 @"Sub", 
                                 nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {

            [action showFromRect:[[self.segmentedControl.subviews objectAtIndex:PostEditorSegmentFormat] frame]
                          inView:[self.segmentedControl.subviews objectAtIndex:PostEditorSegmentFormat] 
                        animated:YES];
    }
        else
            [action showInView:self.view];
}

-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSArray *formats = [NSArray arrayWithObjects:@"Bold", @"Italic", @"Underline", @"Strikethrough", @"Super", @"Sub", nil];
    if (buttonIndex >= formats.count) return;
    [self.replyWebView format:[formats objectAtIndex:buttonIndex]];
    
}

@end
