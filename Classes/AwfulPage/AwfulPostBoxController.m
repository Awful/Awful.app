//
//  AwfulPostBoxController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostBoxController.h"
//#import "AwfulReplyRequest.h"
//#import "AwfulEditRequest.h"
#import "AwfulPage.h"
#import "AwfulThread.h"
#import "AwfulAppDelegate.h"
//#import "AwfulRequestHandler.h"

#define CANCEL_BUTTON 1
#define SEND_BUTTON 2

@implementation AwfulPostBoxController

@synthesize replyTextView, thread, post, startingText;
@synthesize sendButton, toolbar, base;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.

-(id)initWithText : (NSString *)text
{
    if((self = [super initWithNibName:@"AwfulPostBox" bundle:[NSBundle mainBundle]])) {
        NSString *old = [AwfulPostBoxController retrievePost];
        self.startingText = [old stringByAppendingString:text];
        self.post = nil;
        self.thread = nil;
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    if(self.post != nil) {
        [self.sendButton setTitle:@"Edit"];
    } else if(self.thread != nil) {
        [self.sendButton setTitle:@"Reply"];
    }
    
    self.replyTextView.text = self.startingText;
    [self.replyTextView becomeFirstResponder];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    [AwfulPostBoxController savePost:self.replyTextView.text];
    
    self.sendButton = nil;
    self.replyTextView = nil;
    self.toolbar = nil;
    self.base = nil;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}


-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{

}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{

}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    [AwfulPostBoxController savePost:self.replyTextView.text];
    // Release any cached data, images, etc. that aren't in use.
}

-(void)keyboardWillShow:(NSNotification *)notification
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:[[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue]];
    [UIView setAnimationDuration:[[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
    
    CGRect keyboard_rect = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect helpful_rect = [self.view convertRect:keyboard_rect toView:nil];
    CGRect my_rect = [self.view convertRect:self.view.frame toView:nil];
    
    float my_height = MIN(self.view.frame.size.height, my_rect.size.height);
    float best_height = my_height - helpful_rect.size.height;
    
    CGRect frame = self.base.frame;
    frame.size.height = best_height;
    self.base.frame = frame;
    
    [UIView commitAnimations];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1) {
        if(alertView.tag == CANCEL_BUTTON) {
            
        } else if(alertView.tag == SEND_BUTTON) {    
            
            [AwfulPostBoxController savePost:self.replyTextView.text];
            
           /* ASIHTTPRequest *req = nil;
            if(self.thread != nil) {
                req = [[AwfulReplyRequest alloc] initWithReply:self.replyTextView.text forThread:self.thread];
            } else if(self.post != nil) {
                req = [[AwfulEditRequest alloc] initWithAwfulPost:self.post withText:self.replyTextView.text];
            }
            
            NSMutableDictionary *dict;
            if(req.userInfo != nil) {
                dict = [NSMutableDictionary dictionaryWithDictionary:req.userInfo];
                [dict setObject:self forKey:@"waitCallback"];
            } else {
                dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:self, @"waitCallback", nil];
            }
            req.userInfo = dict;
            loadRequestAndWait(req);*/
            [self.replyTextView resignFirstResponder];
        }
    }
}

-(void)hideReply
{
    /*AwfulNavigator *nav = getNavigator();
    [nav.requestHandler cancelAllRequests];
    [AwfulPostBoxController savePost:self.replyTextView.text];
    [self.replyTextView resignFirstResponder];*/
    UIViewController *vc = [ApplicationDelegate getRootController];
    [vc dismissModalViewControllerAnimated:YES];
}

-(void)setThread:(AwfulThread *)aThread 
{
    if(thread != aThread) {
        thread = aThread;
        
        if(self.thread != nil) {
            self.post = nil;
            [self.sendButton setTitle:@"Reply"];
        }
    }
}

-(void)setPost : (AwfulPost *)aPost
{
    if(post != aPost) {
        post = aPost;
        
        if(self.post != nil) {
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
    alert.tag = SEND_BUTTON;
    [alert show];
}

-(void)addText : (NSString *)in_text
{
    if(self.replyTextView.text == nil) {
        self.replyTextView.text = @"";
    }
    self.replyTextView.text = [self.replyTextView.text stringByAppendingString:in_text];
}

+(void)savePost : (NSString *)text
{
    [[NSUserDefaults standardUserDefaults] setObject:text forKey:@"storedPost"];
}

+(NSString *)retrievePost
{
    NSString *post = [[NSUserDefaults standardUserDefaults] objectForKey:@"storedPost"];
    if(post == nil) {
        return @"";
    }
    return post;
}

+(void)clearStoredPost
{
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"storedPost"];
}

@end
