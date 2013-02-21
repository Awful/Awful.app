//
//  AwfulReplyViewController.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposerViewController.h"

@interface AwfulReplyComposerViewController : AwfulComposerViewController

@property (nonatomic) AwfulThread *thread;
@property (nonatomic) AwfulPost *post;
@property (nonatomic,strong) NSString* reply;
@property (nonatomic) NSArray* cellBlocks;

- (id)initWithThread:(AwfulThread *)thread initialContents:(NSString *)contents;

@end
