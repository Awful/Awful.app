//  SmilieKeyboardView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@class Smilie;
#import <Smilies/SmilieListType.h>
@protocol SmilieKeyboardDataSource;
@protocol SmilieKeyboardDelegate;

IB_DESIGNABLE
@interface SmilieKeyboardView : UIView

+ (instancetype)newFromNib;

@property (weak, nonatomic) id <SmilieKeyboardDataSource> dataSource;
@property (weak, nonatomic) id <SmilieKeyboardDelegate> delegate;

@property (assign, nonatomic) SmilieList selectedSmilieList;

@property (readonly, weak, nonatomic) UICollectionView *collectionView;

@property (strong, nonatomic) IBInspectable UIColor *normalBackgroundColor;
@property (strong, nonatomic) IBInspectable UIColor *selectedBackgroundColor;

- (void)reloadData;

@end

@protocol SmilieKeyboardDataSource <NSObject>

@property (assign, nonatomic) SmilieList smilieList;

- (NSInteger)numberOfSectionsInSmilieKeyboard:(SmilieKeyboardView *)keyboardView;
- (NSInteger)smilieKeyboard:(SmilieKeyboardView *)keyboardView numberOfSmiliesInSection:(NSInteger)section;

- (CGSize)smilieKeyboard:(SmilieKeyboardView *)keyboardView sizeOfSmilieAtIndexPath:(NSIndexPath *)indexPath;
- (id /* UIImage or FLAnimatedImage */)smilieKeyboard:(SmilieKeyboardView *)keyboardView imageOfSmilieAtIndexPath:(NSIndexPath *)indexPath;

@end

@protocol SmilieKeyboardDelegate <NSObject>

- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboardView *)keyboardView;
- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboardView *)keyboardView;

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didTapSmilieAtIndexPath:(NSIndexPath *)indexPath;
- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didLongPressSmilieAtIndexPath:(NSIndexPath *)indexPath;

@end
