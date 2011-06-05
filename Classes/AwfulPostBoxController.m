    //
//  AwfulPostBoxController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostBoxController.h"
#import "AwfulNavController.h"
#import "AwfulReplyRequest.h"
#import "AwfulEditRequest.h"
#import "AwfulPage.h"           

#define CLEAR_BUTTON 1
#define SEND_BUTTON 2

@implementation AwfulPostBoxController

@synthesize sendButton, replyTextView;
@synthesize cancelButton, clearButton;
@synthesize buttonGroup;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization.
        post = nil;
        thread = nil;
        startingText = nil;
    }
    return self;
}


-(id)initWithText : (NSString *)text
{
    if((self = [super initWithNibName:@"TextInput" bundle:[NSBundle mainBundle]])) {
        startingText = [text retain];
        post = nil;
        thread = nil;
    }
    return self;
}

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIImage *button_back = [UIImage imageNamed:@"btn_template_bg.png"];
    UIImage *stretch_back = [button_back stretchableImageWithLeftCapWidth:17 topCapHeight:17];
    [sendButton setBackgroundImage:stretch_back forState:UIControlStateNormal];
    [clearButton setBackgroundImage:stretch_back forState:UIControlStateNormal];
    [cancelButton setBackgroundImage:stretch_back forState:UIControlStateNormal];
    
    replyTextView.text = startingText;
    [replyTextView becomeFirstResponder];
}



// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return YES;
}


-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{

}


-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if(UIInterfaceOrientationIsPortrait(fromInterfaceOrientation) && UIInterfaceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
        /*[UIView animateWithDuration:0.2 animations:^(void){
            self.view.transform = CGAffineTransformScale(self.view.transform, 1.0, 0.9);
        }];*/
        
    }
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.buttonGroup = nil;
    self.sendButton = nil;
    self.replyTextView = nil;
    self.clearButton = nil;
    self.cancelButton = nil;
}


- (void)dealloc {
    [buttonGroup release];
    [sendButton release];
    [replyTextView release];
    [clearButton release];
    [cancelButton release];
    [startingText release];
    [super dealloc];
}

-(IBAction)clearReply
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Clear?" message:@"Every post is precious." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Clear Post", nil];
    alert.delegate = self;
    alert.tag = CLEAR_BUTTON;
    [alert show];
    [alert release];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1) {
        if(alertView.tag == CLEAR_BUTTON) {
            replyTextView.text = @"";
        } else if(alertView.tag == SEND_BUTTON) {    
            AwfulNavController *nav = getnav();
            
            ASIHTTPRequest *req = nil;
            
            if(thread != nil) {
                req = [[AwfulReplyRequest alloc] initWithReply:replyTextView.text forThread:thread];
            } else if(post != nil) {
                req = [[AwfulEditRequest alloc] initWithAwfulPost:post withText:replyTextView.text];
            }
            
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:self, @"waitCallback", nil];
            
            req.userInfo = dict;
            
            [nav loadRequestAndWait:req];
            [req release];
        }
    }
}

-(void)hideReply
{
    [replyTextView resignFirstResponder];
    AwfulNavController *nav = getnav();
    [nav dismissModalViewControllerAnimated:YES];
}

-(void)setReplyBox : (AwfulThread *)in_thread
{
    post = nil;
    thread = in_thread;
    
    [sendButton setTitle:@"Send" forState:UIControlStateNormal];
}

-(void)setEditBox : (AwfulPost *)in_post
{
    thread = nil;
    post = in_post;
    
    [sendButton setTitle:@"Save" forState:UIControlStateNormal];
}

-(void)hitSend
{
    NSString *send_title = [sendButton titleForState:UIControlStateNormal];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Are you sure?" message:[NSString stringWithFormat:@"Confirm you want to %@.", send_title] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:send_title, nil];
    alert.delegate = self;
    alert.tag = SEND_BUTTON;
    [alert show];
    [alert release];
}

-(void)addText : (NSString *)in_text
{
    if(replyTextView.text == nil) {
        replyTextView.text = @"";
    }
    replyTextView.text = [replyTextView.text stringByAppendingString:in_text];
}

#pragma mark WaitRequestCallback

-(void)success
{
    replyTextView.text = @"";
    [self hideReply];
}

-(void)failed
{
    
}

@end
