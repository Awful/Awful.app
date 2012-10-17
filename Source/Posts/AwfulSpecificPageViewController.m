//
//  AwfulSpecificPageViewController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSpecificPageViewController.h"
#import "AwfulPage.h"
#import "AwfulThreadListController.h"
#import "ButtonSegmentedControl.h"

@interface AwfulSpecificPageViewController () <UIPickerViewDataSource, UIPickerViewDelegate>

@end


@implementation AwfulSpecificPageViewController

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.page.numberOfPages;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"%d", row+1];
}

#pragma mark - View lifecycle

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 260)];
    self.view.backgroundColor = [UIColor darkGrayColor];
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    toolbar.barStyle = UIBarStyleBlack;
    self.firstLastSegmentedControl = [[ButtonSegmentedControl alloc] initWithItems:@[ @"First", @"Last" ]];
    self.firstLastSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    CGRect bounds = self.firstLastSegmentedControl.bounds;
    bounds.size.width = 115;
    self.firstLastSegmentedControl.bounds = bounds;
    self.firstLastSegmentedControl.target = self;
    self.firstLastSegmentedControl.action = @selector(hitFirstLastSegment:);
    self.firstLastSegmentedControl.tintColor = [UIColor darkGrayColor];
    UIBarButtonItem *firstLast = [[UIBarButtonItem alloc] initWithCustomView:self.firstLastSegmentedControl];
    UIBarButtonItem *separator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    self.jumpToPageBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Jump to Page"
                                                                    style:UIBarButtonItemStyleBordered
                                                                   target:self
                                                                   action:@selector(hitJumpToPage:)];
    self.jumpToPageBarButtonItem.tintColor = [UIColor darkGrayColor];
    toolbar.items = @[ firstLast, separator, self.jumpToPageBarButtonItem ];
    [self.view addSubview:toolbar];
    
    self.pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 44, 320, 216)];
    self.pickerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.pickerView.dataSource = self;
    self.pickerView.delegate = self;
    self.pickerView.showsSelectionIndicator = YES;
    [self.view addSubview:self.pickerView];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (IBAction)hitFirstLastSegment:(id)sender
{
    if (self.firstLastSegmentedControl.selectedSegmentIndex == 0) {
        [self hitFirst:nil];
    } else if (self.firstLastSegmentedControl.selectedSegmentIndex == 1) {
        [self hitLast:nil];
    }
    self.firstLastSegmentedControl.selectedSegmentIndex = -1;
}

- (IBAction)hitJumpToPage:(id)sender 
{
    self.page.destinationType = AwfulPageDestinationTypeSpecific;
    [self.page loadPageNum:[self.pickerView selectedRowInComponent:0]+1];
}

- (IBAction)hitFirst:(id)sender
{
    self.page.destinationType = AwfulPageDestinationTypeSpecific;
    [self.page loadPageNum:1];
}

- (IBAction)hitLast:(id)sender
{
    self.page.destinationType = AwfulPageDestinationTypeSpecific;
    [self.page loadPageNum:self.page.numberOfPages];
}

@end
