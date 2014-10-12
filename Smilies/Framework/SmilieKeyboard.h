//  SmilieKeyboard.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
@class Smilie;
@class SmilieDataStore;
@class SmilieFavoriteToggler;
@class SmilieKeyboardView;
@protocol SmilieKeyboardDelegate;

@interface SmilieKeyboard : NSObject

@property (weak, nonatomic) id <SmilieKeyboardDelegate> delegate;

@property (readonly, strong, nonatomic) SmilieDataStore *dataStore;

@property (readonly, strong, nonatomic) SmilieKeyboardView *view;

@end

@protocol SmilieKeyboardDelegate <NSObject>

- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboard *)keyboard;
- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboard *)keyboard;
- (void)smilieKeyboard:(SmilieKeyboard *)keyboard didTapSmilie:(Smilie *)smilie;
- (void)smilieKeyboard:(SmilieKeyboard *)keyboard presentFavoriteToggler:(SmilieFavoriteToggler *)toggler;

@end
