//
//  AwfulAlertView.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
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
