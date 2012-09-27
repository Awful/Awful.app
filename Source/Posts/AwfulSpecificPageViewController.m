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
    [super loadView];
    [self.jumpToPageBarButtonItem setTintColor:[UIColor darkGrayColor]];
    self.firstLastSegmentedControl.action = @selector(hitFirstLastSegment:);
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
