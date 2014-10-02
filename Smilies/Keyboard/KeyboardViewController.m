//  KeyboardViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "KeyboardViewController.h"
#import "NeedsFullAccessView.h"
@import Smilies;

@interface KeyboardViewController ()

@property (strong, nonatomic) UIButton *nextKeyboardButton;
@property (strong, nonatomic) NeedsFullAccessView *needsFullAccessView;
@property (readonly, assign, nonatomic) BOOL showingFullAccessView;

@end

@implementation KeyboardViewController

- (NeedsFullAccessView *)needsFullAccessView
{
    if (!_needsFullAccessView) {
        _needsFullAccessView = [[NSBundle bundleForClass:[KeyboardViewController class]] loadNibNamed:@"NeedsFullAccessView" owner:self options:nil].firstObject;
    }
    return _needsFullAccessView;
}

- (BOOL)showingFullAccessView
{
    // Direct ivar access to avoid triggering lazy-loading.
    return [self isViewLoaded] && [_needsFullAccessView isDescendantOfView:self.view];
}

- (UIButton *)nextKeyboardButton
{
    if (!_nextKeyboardButton) {
        _nextKeyboardButton = [SmilieNextKeyboardButton new];
    }
    return _nextKeyboardButton;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (HasFullAccess()) {
        self.nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:self.nextKeyboardButton];
        [self.nextKeyboardButton addTarget:self action:@selector(advanceToNextInputMode) forControlEvents:UIControlEventTouchUpInside];
        NSDictionary *views = @{@"nextKeyboard": self.nextKeyboardButton};
        [self.view addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[nextKeyboard(40)]"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self.view addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:[nextKeyboard(54)]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    } else {
        self.needsFullAccessView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view insertSubview:self.needsFullAccessView belowSubview:self.nextKeyboardButton];
        
        NSDictionary *views = @{@"needs": self.needsFullAccessView};
        [self.view addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[needs]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self.view addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[needs]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    }
}

static BOOL HasFullAccess(void) {
    NSURL *groupContainer = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.awfulapp.SmilieKeyboard"];
    return [[NSFileManager defaultManager] isReadableFileAtPath:groupContainer.path];
}

- (IBAction)advanceToNextInputMode
{
    [super advanceToNextInputMode];
}

@end
