//
//  AwfulPrivateMessageViewController.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulTableViewController.h"
#import "AwfulPrivateMessage.h"

@interface AwfulPrivateMessageViewController : UIViewController

- (instancetype)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage;

@property (readonly, nonatomic) AwfulPrivateMessage *privateMessage;

@end
