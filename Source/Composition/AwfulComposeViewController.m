//
//  AwfulComposeViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulKeyboardBar.h"

@interface AwfulComposeViewController ()

@property (nonatomic) AwfulTextView *textView;

@end


@implementation AwfulComposeViewController

- (AwfulTextView *)textView
{
    if (_textView) return _textView;
    _textView = [AwfulTextView new];
    _textView.delegate = self;
    _textView.frame = [UIScreen mainScreen].applicationFrame;
    _textView.font = [UIFont systemFontOfSize:17];
    AwfulKeyboardBar *bbcodeBar = [AwfulKeyboardBar new];
    bbcodeBar.frame = CGRectMake(0, 0, CGRectGetWidth(_textView.bounds),
                                 UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 63 : 36);
    bbcodeBar.characters = @[ @"[", @"=", @":", @"/", @"]" ];
    bbcodeBar.keyInputView = _textView;
    _textView.inputAccessoryView = bbcodeBar;
    return _textView;
}

- (UIBarButtonItem *)sendButton
{
    if (_sendButton) return _sendButton;
    _sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone
                                                  target:nil action:NULL];
    return _sendButton;
}

- (UIBarButtonItem *)cancelButton
{
    if (_cancelButton) return _cancelButton;
    _cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                     style:UIBarButtonItemStyleBordered
                                                    target:nil action:NULL];
    return _cancelButton;
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.navigationItem.rightBarButtonItem = self.sendButton;
    self.navigationItem.leftBarButtonItem = self.cancelButton;
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)keyboardDidShow:(NSNotification *)note
{
    // TODO this is a bad way to do things, as the text view still puts stuff under the keyboard.
    // (for example, autocorrection suggestions)
    // Change the frame of the text view instead.
    CGRect keyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect relativeKeyboardFrame = [self.textView convertRect:keyboardFrame fromView:nil];
    CGRect overlap = CGRectIntersection(relativeKeyboardFrame, self.textView.bounds);
    // The 2 isn't strictly necessary, I just like a little cushion between the cursor and keyboard.
    UIEdgeInsets insets = (UIEdgeInsets){ .bottom = overlap.size.height + 2 };
    self.textView.contentInset = insets;
    self.textView.scrollIndicatorInsets = insets;
    [self.textView scrollRangeToVisible:self.textView.selectedRange];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    self.textView.contentInset = UIEdgeInsetsZero;
    self.textView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) return YES;
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
