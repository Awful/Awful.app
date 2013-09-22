//  AwfulPrivateMessageViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulOldTableViewController.h"
#import "AwfulPrivateMessage.h"

@interface AwfulPrivateMessageViewController : UIViewController

- (instancetype)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage;

@property (readonly, nonatomic) AwfulPrivateMessage *privateMessage;

@end
