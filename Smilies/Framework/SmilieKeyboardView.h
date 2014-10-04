//  SmilieKeyboardView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@class Smilie;

@protocol SmilieKeyboardViewDelegate;

IB_DESIGNABLE
@interface SmilieKeyboardView : UIView

+ (instancetype)newFromNib;

@property (weak, nonatomic) id <SmilieKeyboardViewDelegate> delegate;

@property (strong, nonatomic) IBInspectable UIColor *selectedBackgroundColor;

- (void)reloadData;

@end

@protocol SmilieKeyboardViewDelegate <NSObject>

- (NSInteger)numberOfSectionsInSmilieKeyboard:(SmilieKeyboardView *)keyboardView;
- (NSInteger)smilieKeyboard:(SmilieKeyboardView *)keyboardView numberOfSmiliesInSection:(NSInteger)section;

- (CGSize)smilieKeyboard:(SmilieKeyboardView *)keyboardView sizeOfSmilieAtIndexPath:(NSIndexPath *)indexPath;
- (id /* UIImage or FLAnimatedImage */)smilieKeyboard:(SmilieKeyboardView *)keyboardView imageOfSmilieAtIndexPath:(NSIndexPath *)indexPath;

- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboardView *)keyboardView;
- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboardView *)keyboardView;
- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didTapSmilieAtIndexPath:(NSIndexPath *)indexPath;

@end
