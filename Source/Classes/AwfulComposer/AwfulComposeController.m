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
#import "AwfulDraft.h"

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

-(NSArray*) sections {
    return nil;
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    [self becomeFirstResponder];
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.sections objectAtIndex:section] count];
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* cellIdentifier;
    NSArray* section = [self.sections objectAtIndex:indexPath.section];
    id cellInfo = [section objectAtIndex:indexPath.row];
    
    if ([cellInfo isKindOfClass:[NSString class]]) {
        cellIdentifier = (NSString*)cellInfo;
    }
    else {
        cellIdentifier = [cellInfo objectForKey:AwfulPostCellIdentifierKey];
    }
    
    
    AwfulPostCell* cell = (AwfulPostCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell)
        cell = [[NSClassFromString(cellIdentifier) alloc] initWithStyle:(UITableViewCellStyleValue2) reuseIdentifier:cellIdentifier];
    
    if (cellIdentifier == @"AwfulPostComposerCell")
        self.composerView = ((AwfulPostComposerCell*)cell).composerView;
        
    if ([cellInfo isKindOfClass:[NSDictionary class]]) {
        cell.dictionary = cellInfo;
    }
    
    if (self.draft)
        cell.draft = self.draft;
    
    
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

-(AwfulDraft*) draft {
    if (!_draft) {
        _draft = [AwfulDraft new];
    }
    return _draft;
}


@end
