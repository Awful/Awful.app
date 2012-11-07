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
#import "AwfulPostsViewController.h"
#import "AwfulThreadListController.h"

@interface AwfulSpecificPageViewController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic) UIBarButtonItem *jumpToPageBarButtonItem;

@property (nonatomic) UISegmentedControl *firstLastSegmentedControl;

@end


@implementation AwfulSpecificPageViewController

- (id)init
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _hiding = YES;
    return self;
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

#pragma mark - UIPickerViewDataSource and UIPickerViewDelegate

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

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self init];
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    self.view.backgroundColor = [UIColor darkGrayColor];
    
    CGRect toolbarFrame, pickerFrame;
    CGRectDivide(self.view.bounds, &toolbarFrame, &pickerFrame, 44, CGRectMinYEdge);
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    toolbar.barStyle = UIBarStyleBlack;
    self.firstLastSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[ @"First", @"Last" ]];
    self.firstLastSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    CGRect bounds = self.firstLastSegmentedControl.bounds;
    bounds.size.width = 115;
    self.firstLastSegmentedControl.bounds = bounds;
    [self.firstLastSegmentedControl addTarget:self
                                       action:@selector(hitFirstLastSegment)
                             forControlEvents:UIControlEventValueChanged];
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

@end
