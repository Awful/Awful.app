//  AwfulPrivateMessageViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulPrivateMessage.h"

@interface AwfulPrivateMessageViewController : AwfulViewController

- (instancetype)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage;

@property (readonly, nonatomic) AwfulPrivateMessage *privateMessage;

@end
