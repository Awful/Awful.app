//  KeyboardViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "KeyboardViewController.h"
#import "NeedsFullAccessView.h"
@import Smilies;

@interface KeyboardViewController () <SmilieKeyboardViewDelegate>

@property (strong, nonatomic) SmilieKeyboardView *keyboardView;
@property (strong, nonatomic) NeedsFullAccessView *needsFullAccessView;
@property (strong, nonatomic) NSLayoutConstraint *heightConstraint;

@property (assign, nonatomic) BOOL shouldInvalidateCollectionViewLayoutOnceInLandscape;

@end

@implementation KeyboardViewController

- (SmilieKeyboardView *)keyboardView
{
    if (!_keyboardView) {
        _keyboardView = [SmilieKeyboardView newFromNib];
    }
    return _keyboardView;
}

- (NeedsFullAccessView *)needsFullAccessView
{
    if (!_needsFullAccessView) {
        _needsFullAccessView = [NeedsFullAccessView newFromNib];
    }
    return _needsFullAccessView;
}

- (NSLayoutConstraint *)heightConstraint
{
    if (!_heightConstraint) {
        _heightConstraint = [NSLayoutConstraint constraintWithItem:self.inputView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:0 constant:216];
    }
    return _heightConstraint;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // I found that something within UICollectionViewFlowLayout would crash if the keyboard first appears on a phone in portrait orientation then you rotate to landscape. The problem does not appear if the keyboard first appears in landscape.
    // As a workaround pending further investigation, we can invalidate the collection view's layout the first time we rotate to landscape. No more crashes after that, even if we never manually invalidate the layout ever again.
    if ([UIScreen mainScreen].traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
        if (self.shouldInvalidateCollectionViewLayoutOnceInLandscape) {
            UICollectionViewLayout *layout = [self.keyboardView valueForKeyPath:@"collectionView.collectionViewLayout"];
            [layout invalidateLayout];
            self.shouldInvalidateCollectionViewLayoutOnceInLandscape = NO;
        }
    }
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    if (CGRectGetHeight(self.view.bounds) == 0) return;
    
    [self.view addConstraint:self.heightConstraint];
    self.shouldInvalidateCollectionViewLayoutOnceInLandscape = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIView *mainView;
    
    if (HasFullAccess()) {
        self.keyboardView.delegate = self;
        mainView = self.keyboardView;
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
    NSURL *groupContainer = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.awfulapp.SmilieKeyboard"];
    return [[NSFileManager defaultManager] isReadableFileAtPath:groupContainer.path];
}

// Redeclared as IBAction.
- (IBAction)advanceToNextInputMode
{
    [super advanceToNextInputMode];
}

#pragma mark - SmilieKeyboardViewDelegate

- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboardView *)keyboardView
{
    [self advanceToNextInputMode];
}

- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboardView *)keyboardView
{
    [self.textDocumentProxy deleteBackward];
}

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didTapSmilie:(Smilie *)smilie
{
    [UIPasteboard generalPasteboard].image = smilie.image;
}

@end
