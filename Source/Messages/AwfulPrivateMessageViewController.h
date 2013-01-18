//
//  AwfulPrivateMessageViewController.h
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"
#import "AwfulPrivateMessage.h"
#import "AwfulPostsView.h"

@interface AwfulPrivateMessageViewController : AwfulTableViewController <AwfulPostsViewDelegate>

-(id) initWithPrivateMessage:(AwfulPrivateMessage*)pm;
@property (nonatomic, readonly, strong) AwfulPrivateMessage* privateMessage;
@property (nonatomic, readonly, strong) NSArray* sections;
@end
