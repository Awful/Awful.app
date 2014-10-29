//  SmilieKeyboardView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@class Smilie;
#import <Smilies/SmilieListType.h>
@protocol SmilieKeyboardDataSource;
@protocol SmilieKeyboardViewDelegate;

/**
 An array of smilie keys, with toggles to choose from three different lists: all smilies, favorite smilies, or recently-inserted smilies.
 */
IB_DESIGNABLE
@interface SmilieKeyboardView : UIView <UIInputViewAudioFeedback>

/**
 Loads the keyboard view from its nib. This is probably how you want to initialize a SmilieKeyboardView.
 */
+ (instancetype)newFromNib;

/**
 The data source provides the images and sizes of the smilies.
 */
@property (weak, nonatomic) id <SmilieKeyboardDataSource> dataSource;

/**
 The delegate implements all actions taken by the smilie keyboard view. (Except for dragging favorites; that's handled by the SmilieCollectionViewFlowLayout.)
 */
@property (weak, nonatomic) id <SmilieKeyboardViewDelegate> delegate;

@property (assign, nonatomic) SmilieList selectedSmilieList;

@property (readonly, weak, nonatomic) UICollectionView *collectionView;

/**
 The background color for keys in their normal (i.e. non-highlighted, non-selected) state.
 */
@property (strong, nonatomic) IBInspectable UIColor *normalBackgroundColor;

/**
 The background color for keys when they're highlighted or selected.
 */
@property (strong, nonatomic) IBInspectable UIColor *selectedBackgroundColor;

/**
 Briefly display a short message over the bottom portion of the smilie keyboard, and announce that message via VoiceOver.
 */
- (void)flashMessage:(NSString *)message;

- (void)reloadData;

@end

@protocol SmilieKeyboardDataSource <NSObject>

/**
 The currently-selected smilie list in the keyboard.
 */
@property (assign, nonatomic) SmilieList smilieList;

- (NSInteger)numberOfSectionsInSmilieKeyboard:(SmilieKeyboardView *)keyboardView;
- (NSInteger)smilieKeyboard:(SmilieKeyboardView *)keyboardView numberOfSmiliesInSection:(NSInteger)section;

/**
 Sent when a key's remove button is pressed.
 */
- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView deleteSmilieAtIndexPath:(NSIndexPath *)indexPath;

/**
 Sent when a key that's being dragged moves from one spot to another. The data source could update its underlying collection to reflect this change, or simply keep track of where the dragged key is. Either way, subsequent calls to -smilieKeyboard:numberOfSmiliesInSection: et al should take this move into account.
 */
- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView dragSmilieFromIndexPath:(NSIndexPath *)oldIndexPath toIndexPath:(NSIndexPath *)newIndexPath;

/**
 Sent when a key stops being dragged. It's possible that it hasn't moved at all. If the data source has yet to commit the move to its underlying collection, now is a good time.
 */
- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didFinishDraggingSmilieToIndexPath:(NSIndexPath *)indexPath;

/**
 Calculates the size of the key.
 */
- (CGSize)smilieKeyboard:(SmilieKeyboardView *)keyboardView sizeOfSmilieAtIndexPath:(NSIndexPath *)indexPath;

/**
 Returns either a UIImage or an FLAnimatedImage representing the smilie, or an NSString representing the smilie's text.
 */
- (id /* UIImage or FLAnimatedImage or NSString */)smilieKeyboard:(SmilieKeyboardView *)keyboardView imageOrTextOfSmilieAtIndexPath:(NSIndexPath *)indexPath;

@end

@protocol SmilieKeyboardViewDelegate <NSObject>

/**
 Sent when the "next keyboard" key is tapped.
 */
- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboardView *)keyboardView;

/**
 Sent when the "delete" key is tapped.
 */
- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboardView *)keyboardView;

/**
 Sent when a smilie key is tapped.
 */
- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didTapSmilieAtIndexPath:(NSIndexPath *)indexPath;

/**
 Sent when a smilie key is long-pressed when the keyboard is not showing the favorites list. (The data source handles the moving and deleting that results from a long-press in the favorites list.)
 */
- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didLongPressSmilieAtIndexPath:(NSIndexPath *)indexPath;

/**
 Sent when a key in the silly numbers and decimal section is tapped.
 */
- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didTapNumberOrDecimal:(NSString *)numberOrDecimal;

@end
