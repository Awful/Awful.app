//
//  AwfulComposeController.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeController.h"
#import "AwfulPostComposerView.h"
#import "AwfulPostComposerCell.h"

@interface AwfulComposeController ()

@end

@implementation AwfulComposeController
@synthesize composerView = _composerView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    cellTypes = [NSArray arrayWithObjects:
                  @"AwfulCurrentUserCell",
                  @"AwfulTextFieldCell",
                  @"AwfulTextFieldCell",
                  @"AwfulPostIconCell",
                  @"AwfulPostComposerCell",
                  @"AwfulPostOptionsCell",
                  @"AwfulImageAttachmentCell",
                  nil];
    
    self.title = @"New Post";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemCancel)
                                                                                          target:nil 
                                                                                          action:nil
                                             ];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:self.submitString
                                                                              style:(UIBarButtonItemStyleDone)
                                                                             target:self
                                                                             action:@selector(didTapSubmit:)
                                              ];
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    [self becomeFirstResponder];
}

-(int) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(int) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return cellTypes.count;
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = [cellTypes objectAtIndex:indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell)
        cell = [[NSClassFromString(cellIdentifier) alloc] initWithStyle:(UITableViewCellStyleValue1) reuseIdentifier:cellIdentifier];
    
    if (cellIdentifier == @"AwfulPostComposerCell")
        self.composerView = ((AwfulPostComposerCell*)cell).composerView;
        
    return cell;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 4)
        return 200;
    return 35;
}

-(NSString*)submitString {
    return @"Post";
}

-(void) didTapSubmit:(UIBarButtonItem*)submitButton {
    NSLog(@"submit:");
    NSLog(@"%@", self.composerView.bbcode);
    [self dismissModalViewControllerAnimated:YES];
}


@end
