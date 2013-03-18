//
//  AwfulAlertView.h
//  Awful
//
//  Created by Nolan Waite on 2012-11-16.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulAlertView : UIAlertView

- (id)initWithTitle:(NSString *)title;

+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message
          buttonTitle:(NSString *)buttonTitle
           completion:(void (^)(void))block;

+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message
		noButtonTitle:(NSString *)negativeTitle
	   yesButtonTitle:(NSString *)affirmativeTitle
		 onAcceptance:(void (^)(void))block;

+ (void)showWithTitle:(NSString *)title
                error:(NSError *)error
          buttonTitle:(NSString *)buttonTitle
           completion:(void (^)(void))block;

+ (void)showWithTitle:(NSString *)title error:(NSError *)error buttonTitle:(NSString *)buttonTitle;

- (void)addButtonWithTitle:(NSString *)title block:(void (^)(void))block;

- (void)addCancelButtonWithTitle:(NSString *)title block:(void (^)(void))block;

@end
