//
//  AwfulViewPrivateMessageController.m
//  Awful
//
//  Created by me on 8/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageViewController.h"
#import "AwfulPM.h"
#import "AwfulPostCell.h"
#import "AwfulHTTPClient+PrivateMessages.h"

@interface AwfulPrivateMessageViewController ()

@end

@implementation AwfulPrivateMessageViewController
@synthesize privateMessage = _privateMessage;


-(void) viewDidLoad {
    [super viewDidLoad];
    self.title = self.privateMessage.subject;
}

-(void)setPrivateMessage:(AwfulPM *)privateMessage
{
    if(_privateMessage != privateMessage) {
        _privateMessage = privateMessage;
        self.title = privateMessage.subject;
    }
    if(!privateMessage.content) {
        [self refresh];
    }
}

-(NSArray*) sections {
    if (!_sections) {
        _sections = [NSArray arrayWithObjects:
        
        
        //section 0
        [NSArray arrayWithObjects:
              [NSDictionary dictionaryWithObjectsAndKeys:
               @"From:", AwfulPostCellTextKey,
               self.privateMessage.from, AwfulPostCellDetailKey,
               @"AwfulPostCell", AwfulPostCellIdentifierKey,
               nil
               ],
              
              [NSDictionary dictionaryWithObjectsAndKeys:
               @"Subject:", AwfulPostCellTextKey,
               self.privateMessage.subject, AwfulPostCellDetailKey,
               @"AwfulPostCell", AwfulPostCellIdentifierKey,
               nil
               ],
              
              [NSDictionary dictionaryWithObjectsAndKeys:
               @"Sent", AwfulPostCellTextKey,
               @"self.privateMessage.sent", AwfulPostCellDetailKey,
               @"AwfulPostCell", AwfulPostCellIdentifierKey,
               nil
               ],
         [NSDictionary dictionaryWithObjectsAndKeys:
          @"AwfulPMContentCell", AwfulPostCellIdentifierKey,
          self.privateMessage, @"AwfulPostCellPMKey",
          nil
          ],
         nil],
                  
        //section 1
            [NSArray arrayWithObjects:
              @"AwfulCurrentUserCell",
              [NSDictionary dictionaryWithObjectsAndKeys:
               @"AwfulTextFieldCell", AwfulPostCellIdentifierKey,
               @"To:", AwfulPostCellTextKey,
               self.privateMessage.from, AwfulPostCellDetailKey,
               AwfulDraftAttributes.recipient, AwfulPostCellDraftInputKey,
               nil
               ],
              [NSDictionary dictionaryWithObjectsAndKeys:
               @"AwfulTextFieldCell", AwfulPostCellIdentifierKey,
               @"Subject:", AwfulPostCellTextKey,
               self.privateMessage.subject, AwfulPostCellDetailKey,
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

              
              
                      nil
                      ],
                  
                  nil
                  ];
    }
    return _sections;
}

- (void)refresh
{
    [[AwfulHTTPClient sharedClient] loadPrivateMessage:self.privateMessage
                                         onCompletion:^(NSMutableArray *forums) {
                                              //[self finishedRefreshing];
                                         }
                                              onError:^(NSError *error) {
                                                  //[self finishedRefreshing];
                                                  [ApplicationDelegate requestFailed:error];
                                              }
     ];
}

-(NSString*)submitString {
    return @"Send";
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *cellData = [[self.sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    if ([cellData isKindOfClass:[NSDictionary class]] && (
        [[cellData objectForKey:AwfulPostCellIdentifierKey] isEqualToString:@"AwfulPostComposerCell"] ||
        [[cellData objectForKey:AwfulPostCellIdentifierKey] isEqualToString:@"AwfulPMContentCell"]))
        return 250;
    
    return 44;
}

@end
