//
//  AwfulPrivateMessageViewController.m
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageViewController.h"
#import "AwfulPM.h"
#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulPostCell.h"

@implementation AwfulPrivateMessageViewController

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
                      nil
                      ],
                     
                     nil
                     ];
    }
    return _sections;
}


-(NSString*)submitString {
    return nil;
}
    

@end
