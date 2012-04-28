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

@implementation AwfulPostBoxController

@synthesize replyTextView = _replyTextView;
@synthesize sendButton = _sendButton;
@synthesize thread = _thread;
@synthesize post = _post;
@synthesize startingText = _startingText;
@synthesize networkOperation = _networkOperation;
@synthesize page = _page;
@synthesize segmentedControl = _segmentedControl;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    self.segmentedControl.action = @selector(tappedSegment:);
    
    if(self.post != nil) {
        [self.sendButton setTitle:@"Edit"];
    } else if(self.thread != nil) {
        [self.sendButton setTitle:@"Reply"];
    }
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    
    self.replyTextView.text = self.startingText;
    [self.replyTextView becomeFirstResponder];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

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

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

-(void)tappedSegment : (id)sender
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
            self.networkOperation = [[ApplicationDelegate awfulNetworkEngine] replyToThread:self.thread withText:self.replyTextView.text onCompletion:^{
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
}

-(void)hideReply
{
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    [self.presentingViewController dismissModalViewControllerAnimated:YES];
}

-(void)setThread:(AwfulThread *)aThread 
{
    if(_thread != aThread) {
        _thread = aThread;
        
        if(_thread != nil) {
            self.post = nil;
            [self.sendButton setTitle:@"Reply"];
        }
    }
}

-(void)setPost : (AwfulPost *)aPost
{
    if(_post != aPost) {
        _post = aPost;
        
        if(_post != nil) {
            self.thread = nil;
            [self.sendButton setTitle:@"Edit"];
        }
    }
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
