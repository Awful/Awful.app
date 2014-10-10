//  KeyboardViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "KeyboardViewController.h"
#import "NeedsFullAccessView.h"
@import Smilies;

@interface KeyboardViewController () <SmilieKeyboardDelegate>

@property (strong, nonatomic) SmilieKeyboardView *keyboardView;
@property (strong, nonatomic) NeedsFullAccessView *needsFullAccessView;
@property (strong, nonatomic) NSLayoutConstraint *heightConstraint;

@property (assign, nonatomic) BOOL shouldInvalidateCollectionViewLayoutOnceInLandscape;

@property (strong, nonatomic) SmilieFetchedDataSource *dataSource;

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

- (SmilieFetchedDataSource *)dataSource
{
    if (!_dataSource) {
        _dataSource = [[SmilieFetchedDataSource alloc] initWithDataStore:[SmilieDataStore new]];
    }
    return _dataSource;
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
    
    if (HasFullAccess() || SmilieKeyboardIsAwfulAppActive()) {
        self.keyboardView.dataSource = self.dataSource;
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
    return [[NSFileManager defaultManager] isReadableFileAtPath:SmilieKeyboardSharedContainerURL().path];
}

// Redeclared as IBAction.
- (IBAction)advanceToNextInputMode
{
    [super advanceToNextInputMode];
}

#pragma mark - SmilieKeyboardDelegate

- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboardView *)keyboardView
{
    [self advanceToNextInputMode];
}

- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboardView *)keyboardView
{
    [self.textDocumentProxy deleteBackward];
}

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didTapSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    Smilie *smilie = [self.dataSource smilieAtIndexPath:indexPath];
    if (SmilieKeyboardIsAwfulAppActive()) {
        [self.textDocumentProxy insertText:smilie.text];
    } else {
        [[UIPasteboard generalPasteboard] setData:smilie.imageData forPasteboardType:smilie.imageUTI];
    }
    [smilie.managedObjectContext performBlock:^{
        smilie.metadata.lastUsedDate = [NSDate date];
        NSError *error;
        if (![smilie.managedObjectContext save:&error]) {
            NSLog(@"%s error saving last used date for smilie: %@", __PRETTY_FUNCTION__, error);
        }
    }];
}

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didLongPressSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    Smilie *smilie = [self.dataSource smilieAtIndexPath:indexPath];
    UICollectionViewCell *cell = [keyboardView.collectionView cellForItemAtIndexPath:indexPath];
    SmilieFavoriteToggler *toggler = [[SmilieFavoriteToggler alloc] initWithSmilie:smilie pointingAtView:cell];
    [self presentViewController:toggler animated:NO completion:nil];
}

@end
