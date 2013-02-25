//
//  AwfulPrivateMessageViewController.h
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"
#import "AwfulPrivateMessage.h"

@interface AwfulPrivateMessageViewController : UIViewController

- (instancetype)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage;

@property (readonly, nonatomic) AwfulPrivateMessage *privateMessage;

@end
