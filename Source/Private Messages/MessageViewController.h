//  MessageViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
@class PrivateMessage;

/**
 * A MessageViewController displays a single private message.
 */
@interface MessageViewController : AwfulViewController

- (instancetype)initWithPrivateMessage:(PrivateMessage *)privateMessage NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) PrivateMessage *privateMessage;

@end
