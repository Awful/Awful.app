//
//  AwfulSpecificPageViewController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSpecificPageViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPage.h"
#import "AwfulThreadListController.h"
#import "ButtonSegmentedControl.h"

@interface AwfulSpecificPageViewController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic) UIBarButtonItem *jumpToPageBarButtonItem;

@property (nonatomic) ButtonSegmentedControl *firstLastSegmentedControl;

@end


@implementation AwfulSpecificPageViewController

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.page.thread.numberOfPagesValue;
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"%d", row+1];
}

#pragma mark - View lifecycle

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    self.view.backgroundColor = [UIColor darkGrayColor];
    
    CGRect toolbarFrame, pickerFrame;
    CGRectDivide(self.view.bounds, &toolbarFrame, &pickerFrame, 44, CGRectMinYEdge);
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    toolbar.barStyle = UIBarStyleBlack;
    self.firstLastSegmentedControl = [[ButtonSegmentedControl alloc] initWithItems:@[ @"First", @"Last" ]];
    self.firstLastSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    CGRect bounds = self.firstLastSegmentedControl.bounds;
    bounds.size.width = 115;
    self.firstLastSegmentedControl.bounds = bounds;
    self.firstLastSegmentedControl.target = self;
    self.firstLastSegmentedControl.action = @selector(hitFirstLastSegment);
    self.firstLastSegmentedControl.tintColor = [UIColor darkGrayColor];
    UIBarButtonItem *firstLast = [[UIBarButtonItem alloc] initWithCustomView:self.firstLastSegmentedControl];
    UIBarButtonItem *separator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    self.jumpToPageBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Jump to Page"
                                                                    style:UIBarButtonItemStyleBordered
                                                                   target:self
                                                                   action:@selector(hitJumpToPage)];
    self.jumpToPageBarButtonItem.tintColor = [UIColor darkGrayColor];
    toolbar.items = @[ firstLast, separator, self.jumpToPageBarButtonItem ];
    [self.view addSubview:toolbar];
    
    self.pickerView = [[UIPickerView alloc] initWithFrame:pickerFrame];
    self.pickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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

- (IBAction)hitFirstLastSegment
{
    if (self.firstLastSegmentedControl.selectedSegmentIndex == 0) {
        [self.page loadPage:1];
    } else if (self.firstLastSegmentedControl.selectedSegmentIndex == 1) {
        [self.page loadPage:AwfulPageLast];
    }
    self.firstLastSegmentedControl.selectedSegmentIndex = -1;
}

- (IBAction)hitJumpToPage
{
    [self.page loadPage:[self.pickerView selectedRowInComponent:0] + 1];
}

@end
