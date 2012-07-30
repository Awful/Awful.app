//
//  AwfulComposeNewPostController.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeNewPostController.h"

@interface AwfulComposeNewPostController ()

@end

@implementation AwfulComposeNewPostController

-(NSString*) submitString {
    return @"Post";
}

-(NSArray*) cells {
    if (!_cells) {
        _cells = [NSArray arrayWithObjects:
                  @"AwfulCurrentUserCell",
                  @"AwfulTextFieldCell",
                  @"AwfulTextFieldCell",
                  @"AwfulPostIconCell",
                  @"AwfulPostComposerCell",
                  @"AwfulPostOptionCell",
                  @"AwfulImageAttachmentCell",
                  nil];
    }
    return _cells;
}

@end
