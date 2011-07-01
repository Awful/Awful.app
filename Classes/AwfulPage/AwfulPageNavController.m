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

@implementation AwfulPageNavController

@synthesize picker = _picker;
@synthesize page = _page;
@synthesize pageLabel = _pageLabel;
@synthesize toolbar = _toolbar;

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
    [_pageLabel release];
    [_picker release];
    [_toolbar release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view bringSubviewToFront:self.picker];
    [self.view bringSubviewToFront:self.toolbar];
    
    [self.picker reloadAllComponents];
    if(self.page != nil) {
        [self.picker selectRow:self.page.pages.currentPage-1 inComponent:0 animated:NO];
        self.pageLabel.title = [NSString stringWithFormat:@"Current Page: %d", self.page.pages.currentPage];
    }
}

-(void)viewDidUnload
{
    [super viewDidUnload];
    self.picker = nil;
    self.pageLabel = nil;
    self.toolbar = nil;
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
    return YES;
}

-(IBAction)go
{
    int chosen_page = [self.picker selectedRowInComponent:0] + 1;
    if(self.page != nil) {
        AwfulPage *req_page = [[AwfulPage alloc] initWithAwfulThread:self.page.thread pageNum:chosen_page];
        loadContentVC(req_page);
        [req_page release];
    }
}

-(IBAction)cancel
{
    UIViewController *vc = getRootController();
    [vc dismissModalViewControllerAnimated:YES];
}

@end
