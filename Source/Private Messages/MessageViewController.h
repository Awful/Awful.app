//  MessageViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

/**
 * A MessageViewController displays a single private message.
 */
@interface MessageViewController : AwfulViewController

/**
 * Designated initializer.
 */
- (id)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage;

@property (readonly, strong, nonatomic) AwfulPrivateMessage *privateMessage;

@end
