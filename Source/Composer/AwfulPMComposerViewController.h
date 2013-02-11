//
//  AwfulPMComposerViewController.h
//  Awful
//
//  Created by me on 2/10/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposerViewController.h"
#import "AwfulTitleEntryCell.h"

@interface AwfulPMComposerViewController : AwfulComposerViewController <AwfulTitleEntryCellDelegate,UITextFieldDelegate>

@property (nonatomic,readonly) NSString* sendTo;
@property (nonatomic,readonly) NSString* subject;
@end
