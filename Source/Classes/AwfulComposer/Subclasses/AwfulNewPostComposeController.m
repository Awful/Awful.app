//
//  AwfulComposeNewPostController.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulNewPostComposeController.h"

@interface AwfulNewPostComposeController ()

@end

@implementation AwfulNewPostComposeController

-(NSString*) submitString {
    return @"Post";
}

-(NSArray*) sections {
    if (!_sections) {
        _sections = [NSArray arrayWithObjects:
                  @"AwfulCurrentUserCell",
                  @"AwfulTextFieldCell",
                  @"AwfulPostIconCell",
                  @"AwfulPostComposerCell",
                  @"AwfulPostOptionCell",
                  @"AwfulImageAttachmentCell",
                  nil];
    }
    return _sections;
}


-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 3)
        return 200;
    return 35;
}

@end
