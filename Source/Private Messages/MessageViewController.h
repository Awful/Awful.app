//  MessageViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

/**
 * A MessageViewController displays a single private message.
 */
@interface MessageViewController : AwfulViewController

- (id)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) AwfulPrivateMessage *privateMessage;

@end
