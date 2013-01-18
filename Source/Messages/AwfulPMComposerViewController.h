//
//  AwfulPMReplyViewController.h
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposerViewController.h"

#import "AwfulModels.h"
@interface AwfulPMComposerViewController : AwfulComposerViewController
@property (nonatomic,strong) AwfulPrivateMessage* draft;

-(void) continueDraft:(AwfulPrivateMessage*) draft;
-(void) replyToPrivateMessage:(AwfulPrivateMessage *)message;
@end
