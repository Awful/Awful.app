//
//  AwfulViewPrivateMessageController.h
//  Awful
//
//  Created by me on 8/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeController.h"

@class AwfulPM;

@interface AwfulPrivateMessageViewController : AwfulComposeController
@property (nonatomic,strong) AwfulPM* privateMessage;
@end
