//
//  AwfulComposeThreadReplyController.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadReplyComposeController.h"

@interface AwfulThreadReplyComposeController ()

@end

@implementation AwfulThreadReplyComposeController

-(NSString*) submitString {
    return @"Reply";
}

-(NSArray*) cells {
    if (!_cells) {
        _cells = [NSArray arrayWithObjects:
                  @"AwfulCurrentUserCell",
                  @"AwfulTextFieldCell",
                  @"AwfulPostComposerCell",
                  @"AwfulPostOptionCell",
                  @"AwfulImageAttachmentCell",
                  nil];
    }
    return _cells;
}

@end
