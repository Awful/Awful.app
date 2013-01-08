//
//  AwfulPrivateMessageViewController.m
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageViewController.h"
#import "AwfulPrivateMessage.h"
#import "AwfulPMComposerViewController.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient+PrivateMessages.h"
//#import "AwfulPostCell.h"

#define AwfulPostCellTextKey @"AwfulPostCellTextKey"
#define AwfulPostCellDetailTextKey @"AwfulPostCellDetailTextKey"

@implementation AwfulPrivateMessageViewController
@synthesize privateMessage = _privateMessage;
@synthesize sections = _sections;

-(id) initWithPrivateMessage:(AwfulPrivateMessage*)pm {
    self = [super init];
    _privateMessage = pm;
    return self;
}

-(void) viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = nil;
    
    self.navigationItem.rightBarButtonItem =[[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:(UIBarButtonSystemItemReply)
                                                                  target:self
                                                                  action:@selector(reply)
                                              ];
}

-(BOOL) refreshOnAppear {
    return (self.privateMessage.content == nil);
}

- (void)refresh
{
    [super refresh];
    
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient client]
                             loadPrivateMessage:self.privateMessage andThen:^(NSError *error, AwfulPrivateMessage *message) {
                                 self.refreshing = NO;
                                 [self.tableView reloadData];
                             }];
    
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.sections objectAtIndex:section] count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * const Identifier = @"AwfulPrivateMessageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:Identifier];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *d = [[self.sections objectAtIndex:indexPath.section]
                       objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [d objectForKey:AwfulPostCellTextKey];
    cell.detailTextLabel.text = [d objectForKey:AwfulPostCellDetailTextKey];
    
}

-(NSArray*) sections {
    if (!_sections) {
        _sections = [NSArray arrayWithObjects:
                     //section 0
                     [NSArray arrayWithObjects:
                      [NSDictionary dictionaryWithObjectsAndKeys:
                       @"From:", AwfulPostCellTextKey,
                       self.privateMessage.from, AwfulPostCellDetailTextKey,
                       nil
                       ],
                      
                      [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Subject:", AwfulPostCellTextKey,
                       self.privateMessage.subject, AwfulPostCellDetailTextKey,
                       nil
                       ],
                      
                      [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Sent", AwfulPostCellTextKey,
                       @"self.privateMessage.sent", AwfulPostCellDetailTextKey,
                       nil
                       ],
                      [NSDictionary dictionaryWithObjectsAndKeys:
                       @"AwfulPMContentCell", AwfulPostCellTextKey,
                       self.privateMessage.content, AwfulPostCellDetailTextKey,
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

-(void) reply {
    AwfulPMComposerViewController *writer = [AwfulPMComposerViewController new];
    [writer replyToPrivateMessage:self.privateMessage];
    
    [self.navigationController pushViewController:writer animated:YES];

}


@end
