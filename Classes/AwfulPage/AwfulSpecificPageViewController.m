//
//  AwfulSmallPageController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSpecificPageViewController.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulThread.h"
#import "AwfulForum.h"
#import "AwfulThreadListController.h"
#import "ButtonSegmentedControl.h"
#import <QuartzCore/QuartzCore.h>

@implementation AwfulSpecificPageViewController

@synthesize hiding = _hiding;
@synthesize page = _page;
@synthesize containerView = _containerView;
@synthesize pickerView = _pickerView;
@synthesize jumpToPageBarButtonItem = _jumpToPageBarButtonItem;
@synthesize firstLastSegmentedControl = _firstLastSegmentedControl;

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.page.pages.totalPages;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"%d", row+1];
}

#pragma mark - View lifecycle

-(void)awakeFromNib
{
    
}

-(void)loadView
{
    [super loadView];
    [self.jumpToPageBarButtonItem setTintColor:[UIColor darkGrayColor]];
    self.firstLastSegmentedControl.action = @selector(hitFirstLastSegment:);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

-(IBAction)hitFirstLastSegment : (id)sender
{
    if(self.firstLastSegmentedControl.selectedSegmentIndex == 0) {
        [self hitFirst:nil];
    } else if(self.firstLastSegmentedControl.selectedSegmentIndex == 1) {
        [self hitLast:nil];
    }
    self.firstLastSegmentedControl.selectedSegmentIndex = -1;
}

- (IBAction)hitJumpToPage:(id)sender 
{
    self.page.destinationType = AwfulPageDestinationTypeSpecific;
    [self.page loadPageNum:[self.pickerView selectedRowInComponent:0]+1];
    [self.page tappedPageNav:nil];
}

-(IBAction)hitFirst : (id)sender
{
    self.page.destinationType = AwfulPageDestinationTypeSpecific;
    [self.page loadPageNum:1];
    [self.page tappedPageNav:nil];
}

-(IBAction)hitLast : (id)sender
{
    self.page.destinationType = AwfulPageDestinationTypeSpecific;
    [self.page loadPageNum:self.page.pages.totalPages];
    [self.page tappedPageNav:nil];
}

@end
