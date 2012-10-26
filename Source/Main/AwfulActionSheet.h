//
//  AwfulActionSheet.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulActionSheet : UIActionSheet

// Designated initializer.
- (id)initWithTitle:(NSString *)title;

// UIActionSheet's designated initializer is re-implemented to ignore all parameters except title
// and delegate.

- (void)addButtonWithTitle:(NSString *)title block:(void (^)(void))block;

- (void)addDestructiveButtonWithTitle:(NSString *)title block:(void (^)(void))block;

- (void)addCancelButtonWithTitle:(NSString *)title;

@end
