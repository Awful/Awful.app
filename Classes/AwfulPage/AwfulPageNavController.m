//
//  AwfulPageNavController.m
//  Awful
//
//  Created by Sean Berry on 11/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageNavController.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulAppDelegate.h"
#import "AwfulThread.h"
#import "AwfulForum.h"
#import "AwfulThreadList.h"

@implementation AwfulPageNavController

@synthesize page = _page;
@synthesize toolbar = _toolbar;
@synthesize barTitle = _barTitle;
@synthesize forumButton = _forumButton;
@synthesize pageTextField = _pageTextField;

@synthesize nextButton = _nextButton;
@synthesize prevButton = _prevButton;
@synthesize firstButton = _firstButton;
@synthesize lastButton = _lastButton;

-(id)initWithAwfulPage : (AwfulPage *)page
{
    self = [super initWithNibName:@"AwfulPageNav" bundle:[NSBundle mainBundle]];
    if(self) {
        _page = [page retain];
    }
    return self;
}

-(void)dealloc
{
    [_page release];
    [_toolbar release];
    [_forumButton release];
    [_pageTextField release];
    
    [_nextButton release];
    [_prevButton release];
    [_firstButton release];
    [_lastButton release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view bringSubviewToFront:self.toolbar];
    
    [self.barTitle setTitle:[NSString stringWithFormat:@"Page %d of %d", self.page.pages.currentPage, self.page.pages.totalPages]];
    [self.forumButton setTitle:self.page.thread.forum.name forState:UIControlStateNormal];
    [self.pageTextField setText:[NSString stringWithFormat:@"%d", self.page.pages.currentPage]];
    
    if(self.page.pages.currentPage == 1) {
        [self.prevButton removeFromSuperview];
        [self.firstButton removeFromSuperview];
    }
    
    if(self.page.pages.currentPage == self.page.pages.totalPages) {
        [self.nextButton removeFromSuperview];
        [self.lastButton removeFromSuperview];
    }
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOutside:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
    [tap release];
}

-(void)viewDidUnload
{
    [super viewDidUnload];
    self.barTitle = nil;
    self.toolbar = nil;
    self.forumButton = nil;
    self.pageTextField = nil;
    
    self.nextButton = nil;
    self.prevButton = nil;
    self.firstButton = nil;
    self.lastButton = nil;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if(self.page != nil) {
        return self.page.pages.totalPages;
    }
    return 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"%d", row+1];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

-(IBAction)hitGo : (id)sender
{
    //int chosen_page = [self.picker selectedRowInComponent:0] + 1;
    int chosen_page = [self.pageTextField.text intValue];
    if(self.page != nil) {
        if(chosen_page >= 1 && chosen_page <= self.page.pages.totalPages && chosen_page != self.page.pages.currentPage) {
            AwfulPage *req_page = [[AwfulPage alloc] initWithAwfulThread:self.page.thread pageNum:chosen_page];
            loadContentVC(req_page);
            [req_page release];
        }
    }
}

-(IBAction)hitCancel : (id)sender
{
    UIViewController *vc = getRootController();
    [vc dismissModalViewControllerAnimated:YES];
}

-(IBAction)hitNext : (id)sender
{
    [self.page nextPage];
}

-(IBAction)hitPrev : (id)sender
{
    [self.page prevPage];
}

-(IBAction)hitFirst : (id)sender
{
    AwfulPage *first_page = [[AwfulPage alloc] initWithAwfulThread:self.page.thread startAt:AwfulPageDestinationTypeFirst];
    loadContentVC(first_page);
    [first_page release];
}

-(IBAction)hitLast : (id)sender
{
    if(![self.page.pages onLastPage]) {
        AwfulPage *last_page = [[AwfulPage alloc] initWithAwfulThread:self.page.thread startAt:AwfulPageDestinationTypeLast];
        loadContentVC(last_page);
        [last_page release];
    }
}

-(IBAction)hitForum : (id)sender
{
    if(self.page.thread.forum != nil) {
        AwfulThreadList *list = [[AwfulThreadList alloc] initWithAwfulForum:self.page.thread.forum];
        loadContentVC(list);
        [list release];
    }
}

-(IBAction)tappedOutside : (UITapGestureRecognizer *)tap
{
    [self.pageTextField resignFirstResponder];
}

@end
