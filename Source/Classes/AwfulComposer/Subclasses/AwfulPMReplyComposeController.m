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
#import "AwfulHTTPClient+PrivateMessages.h"

@interface AwfulPMReplyComposeController ()

@end

@implementation AwfulPMReplyComposeController

-(void) viewDidLoad {
    [super viewDidLoad];
    self.title = @"New Private Message";
    self.draft.draftTypeValue = AwfulDraftTypePM;
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
                   @"Post Icon:", AwfulPostCellTextKey,
                   AwfulDraftRelationships.threadTag, AwfulPostCellDraftInputKey,
                   nil
                   ],
                  [NSDictionary dictionaryWithObjectsAndKeys:
                   @"AwfulPostComposerCell", AwfulPostCellIdentifierKey,
                   AwfulDraftAttributes.content, AwfulPostCellDraftInputKey,
                   nil
                   ],
                  [NSDictionary dictionaryWithObjectsAndKeys:
                   @"AwfulPostOptionCell", AwfulPostCellIdentifierKey,
                   @"Parse URLs:", AwfulPostCellTextKey,
                   AwfulDraftAttributes.optionParseURLs, AwfulPostCellDraftInputKey,
                   nil
                   ],
                  [NSDictionary dictionaryWithObjectsAndKeys:
                   @"AwfulPostOptionCell", AwfulPostCellIdentifierKey,
                   @"Show Signature:", AwfulPostCellTextKey,
                   AwfulDraftAttributes.optionShowSignature, AwfulPostCellDraftInputKey,
                   nil
                   ],
                  nil];
    }
    return _cells;
}

-(void) didTapSubmit:(UIBarButtonItem*)submitButton {
    NSLog(@"submit:");
    NSLog(@"%@", self.composerView.bbcode);
    [[AwfulHTTPClient sharedClient] sendPrivateMessage:self.draft onCompletion:nil onError:nil];
    [self dismissModalViewControllerAnimated:YES];
}
@end
