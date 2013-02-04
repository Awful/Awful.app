//
//  AwfulThreadComposerViewController.h
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposerViewController.h"
#import "AwfulModels.h"

@interface AwfulThreadComposerViewController : AwfulComposerViewController
- (id)initWithForum:(AwfulForum*)forum;

@property (nonatomic,readonly) AwfulForum* forum;
@end
