//
//  AwfulEditPostComposerViewController.h
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyComposerViewController.h"

#import "AwfulModels.h"
@interface AwfulEditPostComposerViewController : AwfulReplyComposerViewController

- (void)editPost:(AwfulPost *)post text:(NSString *)text;

@end
