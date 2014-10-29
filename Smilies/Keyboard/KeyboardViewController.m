//  KeyboardViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "KeyboardViewController.h"
#import "NeedsFullAccessView.h"
@import Smilies;

@interface KeyboardViewController () <SmilieKeyboardDelegate>

@property (strong, nonatomic) SmilieKeyboard *keyboard;
@property (strong, nonatomic) NeedsFullAccessView *needsFullAccessView;

@end

@implementation KeyboardViewController

- (SmilieKeyboard *)keyboard
{
    if (!_keyboard) {
        _keyboard = [SmilieKeyboard new];
        _keyboard.delegate = self;
    }
    return _keyboard;
}

- (NeedsFullAccessView *)needsFullAccessView
{
    if (!_needsFullAccessView) {
        _needsFullAccessView = [NeedsFullAccessView newFromNib];
    }
    return _needsFullAccessView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIView *mainView;
    
    if (HasFullAccess() || SmilieKeyboardIsAwfulAppActive()) {
        mainView = self.keyboard.view;
    } else {
        mainView = self.needsFullAccessView;
    }
    
    mainView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mainView];
    
    NSDictionary *views = @{@"main": mainView};
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[main]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[main]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
}

static BOOL HasFullAccess(void)
{
    return [[NSFileManager defaultManager] isReadableFileAtPath:SmilieKeyboardSharedContainerURL().path];
}

// Redeclared as IBAction.
- (IBAction)advanceToNextInputMode
{
    [super advanceToNextInputMode];
}

#pragma mark - SmilieKeyboardDelegate

- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboard *)keyboard
{
    [self advanceToNextInputMode];
}

- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboard *)keyboard
{
    [self.textDocumentProxy deleteBackward];
}

- (void)smilieKeyboard:(SmilieKeyboard *)keyboard didTapSmilie:(Smilie *)smilie
{
    if (SmilieKeyboardIsAwfulAppActive()) {
        [self.textDocumentProxy insertText:smilie.text];
    } else {
        [[UIPasteboard generalPasteboard] setData:smilie.imageData forPasteboardType:smilie.imageUTI];
        [keyboard.view flashMessage:[NSString stringWithFormat:@"Copied %@", smilie.text]];
    }
    [smilie.managedObjectContext performBlock:^{
        smilie.metadata.lastUsedDate = [NSDate date];
        NSError *error;
        if (![smilie.managedObjectContext save:&error]) {
            NSLog(@"%s error saving last used date for smilie: %@", __PRETTY_FUNCTION__, error);
        }
    }];
}

- (void)smilieKeyboard:(SmilieKeyboard *)keyboard insertNumberOrDecimal:(NSString *)numberOrDecimal
{
    [self.textDocumentProxy insertText:numberOrDecimal];
}

@end
