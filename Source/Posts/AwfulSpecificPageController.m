//
//  AwfulSpecificPageController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSpecificPageController.h"
#import "AwfulHTTPClient.h"

@interface AwfulSpecificPageController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (weak, nonatomic) UIPickerView *pickerView;

@property (weak, nonatomic) UIBarButtonItem *jumpToPageBarButtonItem;

@property (weak, nonatomic) UISegmentedControl *firstLastSegmentedControl;

@end


@implementation AwfulSpecificPageController

- (UIPickerView *)pickerView
{
    if (_pickerView) return _pickerView;
    [self view];
    return _pickerView;
}

- (void)reloadPages
{
    [self.pickerView reloadAllComponents];
    [self.pickerView selectRow:[self.delegate currentPageForSpecificPageController:self] - 1
                   inComponent:0
                      animated:NO];
}

- (void)showInView:(UIView *)view animated:(BOOL)animated
{
    CGRect endFrame = CGRectMake(0, view.frame.size.height - self.view.frame.size.height,
                                 view.frame.size.width, self.view.frame.size.height);
    if (animated) {
        self.view.frame = CGRectMake(0, view.frame.size.height,
                                     view.frame.size.width, self.view.frame.size.height);
        [view addSubview:self.view];
        [UIView animateWithDuration:0.3 animations:^{
            self.view.frame = endFrame;
        }];
    } else {
        self.view.frame = endFrame;
        [view addSubview:self.view];
    }
}

- (void)hideAnimated:(BOOL)animated
{
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^
        {
            CGRect frame = self.view.frame;
            frame.origin.y += frame.size.height;
            self.view.frame = frame;
        } completion:^(BOOL _)
        {
            [self.view removeFromSuperview];
        }];
    } else {
        [self.view removeFromSuperview];
    }
}

- (void)hitFirstLastSegment
{
    if (self.firstLastSegmentedControl.selectedSegmentIndex == 0) {
        [self.delegate specificPageController:self didSelectPage:1];
    } else if (self.firstLastSegmentedControl.selectedSegmentIndex == 1) {
        [self.delegate specificPageController:self didSelectPage:AwfulPageLast];
    }
    self.firstLastSegmentedControl.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)hitJumpToPage
{
    NSInteger page = [self.pickerView selectedRowInComponent:0] + 1;
    [self.delegate specificPageController:self didSelectPage:page];
}

#pragma mark - UIPickerViewDataSource and UIPickerViewDelegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return [self.delegate numberOfPagesInSpecificPageController:self];
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"%d", row + 1];
}

#pragma mark - UIViewController

- (void)loadView
{
    CGFloat toolbarHeight = 44;
    CGFloat validPickerHeight = 162;
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
                                                         320, toolbarHeight + validPickerHeight)];
    self.view.backgroundColor = [UIColor darkGrayColor];
    
    CGRect toolbarFrame, pickerFrame;
    CGRectDivide(self.view.bounds, &toolbarFrame, &pickerFrame, 44, CGRectMinYEdge);
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    toolbar.barStyle = UIBarStyleBlack;
    UISegmentedControl *firstLastSegmentedControl = [[UISegmentedControl alloc]
                                                     initWithItems:@[ @"First", @"Last" ]];
    self.firstLastSegmentedControl = firstLastSegmentedControl;
    firstLastSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    CGRect bounds = firstLastSegmentedControl.bounds;
    bounds.size.width = 115;
    firstLastSegmentedControl.bounds = bounds;
    [firstLastSegmentedControl addTarget:self
                                  action:@selector(hitFirstLastSegment)
                        forControlEvents:UIControlEventValueChanged];
    firstLastSegmentedControl.tintColor = [UIColor darkGrayColor];
    UIBarButtonItem *firstLast = [[UIBarButtonItem alloc]
                                  initWithCustomView:self.firstLastSegmentedControl];
    UIBarButtonItem *separator = [[UIBarButtonItem alloc]
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                  target:nil
                                  action:NULL];
    UIBarButtonItem *jumpToPageBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithTitle:@"Jump to Page"
                                                style:UIBarButtonItemStyleBordered
                                                target:self
                                                action:@selector(hitJumpToPage)];
    self.jumpToPageBarButtonItem = jumpToPageBarButtonItem;
    jumpToPageBarButtonItem.tintColor = [UIColor darkGrayColor];
    toolbar.items = @[ firstLast, separator, jumpToPageBarButtonItem ];
    [self.view addSubview:toolbar];
    
    UIPickerView *pickerView = [[UIPickerView alloc] initWithFrame:pickerFrame];
    pickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    pickerView.dataSource = self;
    pickerView.delegate = self;
    pickerView.showsSelectionIndicator = YES;
    [self.view addSubview:pickerView];
    self.pickerView = pickerView;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
