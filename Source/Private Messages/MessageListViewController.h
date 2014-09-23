//  MessageListViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulDataStack.h"

/**
 * A MessageListViewController shows a list of private messages.
 */
@interface MessageListViewController : AwfulTableViewController

- (instancetype)initWithDataStack:(AwfulDataStack *)dataStack NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) AwfulDataStack *dataStack;

@end
