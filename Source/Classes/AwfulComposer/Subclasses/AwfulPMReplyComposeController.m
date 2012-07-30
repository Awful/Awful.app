//
//  AwfulPMReplyComposeController.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPMReplyComposeController.h"

@interface AwfulPMReplyComposeController ()

@end

@implementation AwfulPMReplyComposeController

-(NSString*) submitString {
    return @"Send";
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
                  nil];
    }
    return _cells;
}
@end
