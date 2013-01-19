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

#define AwfulPostCellTextKey @"AwfulPostCellTextKey"
#define AwfulPostCellDetailTextKey @"AwfulPostCellDetailTextKey"


@implementation AwfulPrivateMessageViewController
@synthesize privateMessage = _privateMessage;
@synthesize sections = _sections;

-(id) initWithPrivateMessage:(AwfulPrivateMessage*)pm {
    self = [super initWithStyle:UITableViewStyleGrouped];
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
    self.title = self.privateMessage.subject;
}

-(BOOL) canPullForNextPage {
    return NO;
}

-(BOOL) canPullToRefresh {
    return NO;
}


-(BOOL) refreshOnAppear {
    return (self.privateMessage.innerHTML == nil);
}

- (void)refresh
{
    [super refresh];
    
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient client]
                             loadPrivateMessage:self.privateMessage andThen:^(NSError *error, AwfulPrivateMessage *message) {
                                 self.refreshing = NO;
                                 [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1]]
                                                       withRowAnimation:(UITableViewRowAnimationFade)];
                                 
                             }];
    
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0? 3: 1;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if (indexPath.section == 0) {
        static NSString * const Identifier = @"AwfulPrivateMessageCell";
        cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:Identifier];
        }
        [self configureCell:cell atIndexPath:indexPath];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"test"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"test"];
            
            cell.textLabel.text = self.privateMessage.innerHTML;
            cell.textLabel.font = [UIFont systemFontOfSize:12];
            cell.textLabel.numberOfLines = 0;
        }
        
        
    }
    
    
    return cell;
}

-(void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"From:";
            cell.detailTextLabel.text = self.privateMessage.from.username;
            break;
            
        case 1:
            cell.textLabel.text = @"Subject:";
            cell.detailTextLabel.text = self.privateMessage.subject;
            break;
            
        case 2:
            cell.textLabel.text = @"Sent:";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", self.privateMessage.sent];
            break;  
    }

}

-(NSString*)submitString {
    return nil;
}

-(void) reply {
    //AwfulPMComposerViewController *writer = [AwfulPMComposerViewController new];
    //[writer replyToPrivateMessage:self.privateMessage];
    
    //[self.navigationController pushViewController:writer animated:YES];

}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0? 44: 500;
}

@end
