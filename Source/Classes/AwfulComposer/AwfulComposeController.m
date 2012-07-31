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
#import "AwfulThreadTagPickerController.h"

@interface AwfulComposeController ()

@end

@implementation AwfulComposeController
@synthesize composerView = _composerView;

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"New Post";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemCancel)
                                                                                          target:self
                                                                                          action:@selector(didTapCancel:)
                                             ];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:self.submitString
                                                                              style:(UIBarButtonItemStyleDone)
                                                                             target:self
                                                                             action:@selector(didTapSubmit:)
                                              ];
    

}

-(NSArray*) cells {
    return nil;
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    [self becomeFirstResponder];
}

-(int) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(int) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cells.count;
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = [self.cells objectAtIndex:indexPath.row];
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

-(void) didTapCancel:(UIBarButtonItem*)cancelButton {
    [self dismissModalViewControllerAnimated:YES];
}

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulPostCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    [cell didSelectCell:self];
}


@end
