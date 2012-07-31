//
//  AwfulPMReplyComposeController.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPMReplyComposeController.h"
#import "AwfulPostCell.h"
#import "AwfulPostComposerView.h"
#import "AwfulDraft.h"

@interface AwfulPMReplyComposeController ()

@end

@implementation AwfulPMReplyComposeController

-(void) viewDidLoad {
    [super viewDidLoad];
    self.title = @"New Private Message";
    //self.draft.draftTypeValue = AwfulDraftTypePM;
}

-(NSString*) submitString {
    return @"Send";
}

-(NSArray*) cells {
    if (!_cells) {
        _cells = [NSArray arrayWithObjects:
                  @"AwfulCurrentUserCell",
                  [NSDictionary dictionaryWithObjectsAndKeys:
                   @"AwfulTextFieldCell", AwfulPostCellIdentifierKey,
                   @"Recipient:", AwfulPostCellTextKey,
                   AwfulDraftAttributes.recipient, AwfulPostCellDraftInputKey,
                   nil
                   ],
                  [NSDictionary dictionaryWithObjectsAndKeys:
                   @"AwfulTextFieldCell", AwfulPostCellIdentifierKey,
                   @"Subject:", AwfulPostCellTextKey,
                   AwfulDraftAttributes.subject, AwfulPostCellDraftInputKey,
                   nil
                   ],
                  [NSDictionary dictionaryWithObjectsAndKeys:
                   @"AwfulPostIconCell", AwfulPostCellIdentifierKey,
                   @"Thread Tag:", AwfulPostCellTextKey,
                   AwfulDraftRelationships.threadTag, AwfulPostCellDraftInputKey,
                   nil
                   ],
                  @"AwfulPostComposerCell",
                  @"AwfulPostOptionCell",
                  nil];
    }
    return _cells;
}

-(void) didTapSubmit:(UIBarButtonItem*)submitButton {
    NSLog(@"submit:");
    NSLog(@"%@", self.composerView.bbcode);
    [self dismissModalViewControllerAnimated:YES];
}
@end
