//
//  AwfulSmallPageController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSmallPageController.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulThread.h"
#import "AwfulForum.h"
#import "AwfulThreadList.h"
#import <QuartzCore/QuartzCore.h>

@implementation AwfulSmallPageController

@synthesize hiding, submitting, page, segment, forumButton;

-(id)initWithAwfulPage : (AwfulPage *)aPage
{
    if((self=[super initWithNibName:@"AwfulSmallPageController" bundle:[NSBundle mainBundle]])) {
        self.hiding = NO;
        self.page = aPage;
        self.submitting = NO;
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
    // Do any additional setup after loading the view from its nib.
    
    if(self.page.pages.currentPage == self.page.pages.totalPages) {
        [self.segment setEnabled:NO forSegmentAtIndex:2];
        [self.segment setEnabled:NO forSegmentAtIndex:3];
    }
    
    if(self.page.pages.currentPage == 1) {
        [self.segment setEnabled:NO forSegmentAtIndex:0];
        [self.segment setEnabled:NO forSegmentAtIndex:1];
    }
    
    self.forumButton.titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:11.0f];
    [self.forumButton.layer setCornerRadius:4.0f];
    [self.forumButton.layer setMasksToBounds:YES];
    [self.forumButton.layer setBorderWidth:1.0f];
    [self.forumButton.layer setBorderColor: [[UIColor colorWithWhite:0.2 alpha:1.0] CGColor]];
    [self.forumButton setTitle:self.page.thread.forum.name forState:UIControlStateNormal];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.segment = nil;
    self.forumButton = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(IBAction)selected : (UISegmentedControl *)sender
{
    float delay = 0.25;
    if(!self.submitting) {
        self.submitting = YES;
        if(sender.selectedSegmentIndex == 0) {
            [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(hitFirst) userInfo:nil repeats:NO];
        } else if(sender.selectedSegmentIndex == 1) {
            [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(hitPrev) userInfo:nil repeats:NO];
        } else if(sender.selectedSegmentIndex == 2) {
            [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(hitNext) userInfo:nil repeats:NO];
        } else if(sender.selectedSegmentIndex == 3) {
            [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(hitLast) userInfo:nil repeats:NO];
        }
    }
}

-(IBAction)hitNext
{
    [self.page nextPage];
}

-(IBAction)hitPrev
{
    [self.page prevPage];
}

-(IBAction)hitFirst
{
    AwfulPage *first_page = [[AwfulPage alloc] initWithAwfulThread:self.page.thread startAt:AwfulPageDestinationTypeFirst];
    loadContentVC(first_page);
}

-(IBAction)hitLast
{
    if(![self.page.pages onLastPage]) {
        AwfulPage *last_page = [[AwfulPage alloc] initWithAwfulThread:self.page.thread startAt:AwfulPageDestinationTypeLast];
        loadContentVC(last_page);
    }
}

-(IBAction)hitForum : (id)sender
{
    if(self.page.thread.forum != nil) {
        AwfulThreadList *list = [[AwfulThreadList alloc] initWithAwfulForum:self.page.thread.forum];
        loadContentVC(list);
    }
}

@end
