//
//  AwfulNavigatorLabels.m
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulNavigatorLabels.h"

@implementation AwfulNavigatorLabels

@synthesize pagesLabel = _pagesLabel;
@synthesize forumLabel = _forumLabel;
@synthesize threadTitleLabel = _threadTitleLabel;

-(id)init 
{
    if((self=[super initWithNibName:@"AwfulNavigatorLabels" bundle:[NSBundle mainBundle]])) {
        if(self.view) {
            
        }
    }
    return self;
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.pagesLabel = nil;
    self.forumLabel = nil;
    self.threadTitleLabel = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

@end
