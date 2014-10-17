//  SmilieKeyboard.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
@class Smilie;
@class SmilieDataStore;
@class SmilieFavoriteToggler;
@class SmilieKeyboardView;
@protocol SmilieKeyboardDelegate;

/**
 A controller object for a smilie keyboard view and its backing store of smilies. This is typically how one uses Smilie.framework: initialize a SmilieKeyboard, then use its view as a text field's inputView.
 
 Actions are handled by the delegate, which you should be sure to set.
 */
@interface SmilieKeyboard : NSObject

@property (weak, nonatomic) id <SmilieKeyboardDelegate> delegate;

@property (readonly, strong, nonatomic) SmilieDataStore *dataStore;

@property (readonly, strong, nonatomic) SmilieKeyboardView *view;

@end

@protocol SmilieKeyboardDelegate <NSObject>

/**
 Sent when the "next keyboard" key is tapped.
 */
- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboard *)keyboard;

/**
 Sent when the "delete" key is tapped.
 */
- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboard *)keyboard;

/**
 Sent when a smilie is tapped. Possible actions include adding the smilie's `imageData` to a pasteboard (see also the `imageUTI`), or inserting the smilie's `text` into the first responder.
 */
- (void)smilieKeyboard:(SmilieKeyboard *)keyboard didTapSmilie:(Smilie *)smilie;

@end
