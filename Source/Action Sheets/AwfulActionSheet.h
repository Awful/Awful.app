//
//  AwfulActionSheet.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import <UIKit/UIKit.h>

@interface AwfulActionSheet : UIActionSheet

// Designated initializer.
- (id)initWithTitle:(NSString *)title;

// UIActionSheet's designated initializer is re-implemented to ignore all parameters except title
// and delegate.

- (void)addButtonWithTitle:(NSString *)title block:(void (^)(void))block;

- (void)addDestructiveButtonWithTitle:(NSString *)title block:(void (^)(void))block;

- (void)addCancelButtonWithTitle:(NSString *)title block:(void (^)(void))block;

- (void)addCancelButtonWithTitle:(NSString *)title;

@end
