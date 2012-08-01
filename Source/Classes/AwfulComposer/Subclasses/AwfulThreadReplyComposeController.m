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
@synthesize thread = _thread;

-(void) viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.prompt = self.thread.title;
    self.title = @"New Reply";
}

-(NSString*) submitString {
    return @"Reply";
}

-(NSArray*) cells {
    if (!_cells) {
        _cells = [NSArray arrayWithObjects:
                  @"AwfulCurrentUserCell",
                  @"AwfulPostComposerCell",
                  @"AwfulPostOptionCell",
                  @"AwfulPostOptionCell",
                  @"AwfulPostOptionCell",
                  @"AwfulPostOptionCell",
                  @"AwfulImageAttachmentCell",
                  nil];
    }
    return _cells;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 1)
        return 200;
    return 35;
}

@end
