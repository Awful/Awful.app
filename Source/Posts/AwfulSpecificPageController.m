//
//  AwfulSpecificPageController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSpecificPageController.h"
#import "AwfulHTTPClient.h"

@interface SpecificTopBarView : UIView

@property (weak, nonatomic) UISegmentedControl *firstLastControl;

@property (weak, nonatomic) UIButton *jumpButton;

@end


@interface AwfulSpecificPageController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (weak, nonatomic) UIPickerView *pickerView;

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

- (void)hideAnimated:(BOOL)animated completion:(void (^)(void))completionBlock
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
            if (completionBlock) completionBlock();
        }];
    } else {
        [self.view removeFromSuperview];
    }
}

- (void)hitFirstLastSegment:(UISegmentedControl *)sender
{
    if (sender.selectedSegmentIndex == 0) {
        [self.delegate specificPageController:self didSelectPage:1];
    } else if (sender.selectedSegmentIndex == 1) {
        [self.delegate specificPageController:self didSelectPage:AwfulPageLast];
    }
    sender.selectedSegmentIndex = UISegmentedControlNoSegment;
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
    CGFloat toolbarHeight = 38;
    CGFloat validPickerHeight = 162;
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
                                                         320, toolbarHeight + validPickerHeight)];
    self.view.backgroundColor = [UIColor darkGrayColor];
    
    CGRect topBarFrame, pickerFrame;
    CGRectDivide(self.view.bounds, &topBarFrame, &pickerFrame, toolbarHeight, CGRectMinYEdge);
    
    SpecificTopBarView *topBar = [[SpecificTopBarView alloc] initWithFrame:topBarFrame];
    topBar.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                               UIViewAutoresizingFlexibleBottomMargin);
    [topBar.firstLastControl addTarget:self
                                action:@selector(hitFirstLastSegment:)
                      forControlEvents:UIControlEventValueChanged];
    [topBar.jumpButton addTarget:self
                          action:@selector(hitJumpToPage)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:topBar];
    
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


@implementation SpecificTopBarView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UIImage *back = [[UIImage imageNamed:@"pagebar.png"]
                     resizableImageWithCapInsets:UIEdgeInsetsZero];
    self.backgroundColor = [UIColor colorWithPatternImage:back];
    
    UIImage *button = [[UIImage imageNamed:@"pagebar-button.png"]
                       resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    UIImage *selected = [[UIImage imageNamed:@"pagebar-button-selected.png"]
                         resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    
    UISegmentedControl *firstLastControl = [[UISegmentedControl alloc]
                                            initWithItems:@[ @"First", @"Last" ]];
    CGSize contentOffset = CGSizeMake(0, 1);
    for (NSUInteger i = 0; i < firstLastControl.numberOfSegments; i++) {
        [firstLastControl setContentOffset:contentOffset forSegmentAtIndex:i];
    }
    NSDictionary *titleAttributes = @{
        UITextAttributeFont: [UIFont boldSystemFontOfSize:11],
        UITextAttributeTextColor: [UIColor whiteColor],
        UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetZero],
    };
    [firstLastControl setTitleTextAttributes:titleAttributes forState:UIControlStateNormal];
    [firstLastControl setBackgroundImage:button
                                forState:UIControlStateNormal
                              barMetrics:UIBarMetricsDefault];
    [firstLastControl setBackgroundImage:selected
                                forState:UIControlStateSelected
                              barMetrics:UIBarMetricsDefault];
    [firstLastControl setDividerImage:[UIImage imageNamed:@"pagebar-segmented-divider.png"]
                  forLeftSegmentState:UIControlStateNormal
                    rightSegmentState:UIControlStateNormal
                           barMetrics:UIBarMetricsDefault];
    [self addSubview:firstLastControl];
    _firstLastControl = firstLastControl;
    
    UIButton *jumpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [jumpButton setTitle:@"Jump to Page" forState:UIControlStateNormal];
    [jumpButton setBackgroundImage:button forState:UIControlStateNormal];
    [jumpButton setBackgroundImage:selected forState:UIControlStateSelected];
    jumpButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self addSubview:jumpButton];
    _jumpButton = jumpButton;
    return self;
}

- (void)layoutSubviews
{
    CGRect segFrame = self.firstLastControl.frame;
    segFrame.origin.x = 7;
    segFrame.size.width = 115;
    segFrame.size.height = 29;
    self.firstLastControl.frame = segFrame;
    self.firstLastControl.center = CGPointMake(self.firstLastControl.center.x,
                                               CGRectGetMidY(self.bounds));
    self.firstLastControl.frame = CGRectIntegral(self.firstLastControl.frame);
    
    CGRect buttonFrame = self.jumpButton.frame;
    buttonFrame.size.width = 115;
    buttonFrame.size.height = 29;
    buttonFrame.origin.x = self.bounds.size.width - buttonFrame.size.width - 7;
    self.jumpButton.frame = buttonFrame;
    self.jumpButton.center = CGPointMake(self.jumpButton.center.x, CGRectGetMidY(self.bounds));
    self.jumpButton.frame = CGRectIntegral(self.jumpButton.frame);
}

@end
