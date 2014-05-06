//  AwfulActionSheet.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulActionSheet adds block-based methods to UIActionSheet.
 */
@interface AwfulActionSheet : UIActionSheet

/**
 * Designated initializer.
 */
- (id)initWithTitle:(NSString *)title;

/**
 * Ignores all parameters except title and delegate.
 */
- (id)initWithTitle:(NSString *)title delegate:(id<UIActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...;

/**
 * Add a button and call a block if it's chosen.
 */
- (void)addButtonWithTitle:(NSString *)title block:(void (^)(void))block;

/**
 * Add a destructive button and call a block if it's chosen.
 */
- (void)addDestructiveButtonWithTitle:(NSString *)title block:(void (^)(void))block;

/**
 * Add a cancel button and call a block if it's chosen.
 */
- (void)addCancelButtonWithTitle:(NSString *)title block:(void (^)(void))block;

/**
 * Add a cancel button.
 */
- (void)addCancelButtonWithTitle:(NSString *)title;

/**
 * Call a block after the action sheet is dismissed.
 */
- (void)setCompletionBlock:(void (^)(void))completionBlock;

@end
