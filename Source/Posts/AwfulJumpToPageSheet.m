//
//  AwfulJumpToPageSheet.m
//  Awful
//
//  Copyright 2011 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulJumpToPageSheet.h"

@interface SpecificTopBarView : UIView

@property (weak, nonatomic) UISegmentedControl *firstLastControl;

@property (weak, nonatomic) UIButton *jumpButton;

@end


@interface AwfulJumpToPageSheet () <UIPickerViewDataSource, UIPickerViewDelegate,
                                    UIPopoverControllerDelegate>

@property (weak, nonatomic) SpecificTopBarView *topBar;

@property (weak, nonatomic) UIPickerView *pickerView;

@property (nonatomic) UIPopoverController *popover;

@property (weak, nonatomic) UIView *halfBlackView;

@end


@implementation AwfulJumpToPageSheet

const CGFloat topBarHeight = 38;

// UIPickerView has few valid heights. Look them up before changing.
const CGFloat pickerHeight = 162;

- (instancetype)initWithDelegate:(id <AwfulJumpToPageSheetDelegate>)delegate
{
    _delegate = delegate;
    CGRect frame = (CGRect){ .size = { 320, topBarHeight + pickerHeight } };
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = [UIColor darkGrayColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    SpecificTopBarView *topBar = [SpecificTopBarView new];
    topBar.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                               UIViewAutoresizingFlexibleBottomMargin);
    [topBar.firstLastControl addTarget:self action:@selector(didTapFirstLastSegment:)
                      forControlEvents:UIControlEventValueChanged];
    [topBar.jumpButton addTarget:self action:@selector(jumpToSelectedPage)
                forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:topBar];
    self.topBar = topBar;
    
    UIPickerView *pickerView = [UIPickerView new];
    pickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    pickerView.dataSource = self;
    pickerView.delegate = self;
    pickerView.showsSelectionIndicator = YES;
    [self addSubview:pickerView];
    self.pickerView = pickerView;
    
    return self;
}

- (void)didTapFirstLastSegment:(UISegmentedControl *)seg
{
    if (seg.selectedSegmentIndex == 0) {
        [self.delegate jumpToPageSheet:self didSelectPage:1];
    } else if (seg.selectedSegmentIndex == 1) {
        [self.delegate jumpToPageSheet:self didSelectPage:AwfulThreadPageLast];
    }
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
    [self dismiss];
}

- (void)jumpToSelectedPage
{
    NSInteger page = [self.pickerView selectedRowInComponent:0] + 1;
    [self.delegate jumpToPageSheet:self didSelectPage:page];
    [self dismiss];
}

- (void)showInView:(UIView *)view behindSubview:(UIView *)subview
{
    [self.pickerView reloadAllComponents];
    [self.pickerView selectRow:[self.delegate initialPageForJumpToPageSheet:self] - 1
                   inComponent:0
                      animated:NO];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self showFromView:subview];
        return;
    }
    if (self.superview) return;
    UIView *halfBlack = [UIView new];
    halfBlack.frame = (CGRect){ .size = view.frame.size };
    halfBlack.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    halfBlack.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleHeight);
    halfBlack.alpha = 0;
    UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
    [tap addTarget:self action:@selector(didTapHalfBlackView:)];
    [halfBlack addGestureRecognizer:tap];
    [view insertSubview:halfBlack belowSubview:subview];
    self.halfBlackView = halfBlack;
    
    CGRect frame = self.frame;
    frame.origin.y = CGRectGetMinY(subview.frame);
    frame.size.width = CGRectGetWidth(view.frame);
    self.frame = frame;
    [view insertSubview:self belowSubview:subview];
    
    [UIView animateWithDuration:0.3 animations:^{
        halfBlack.alpha = 1;
        CGRect targetFrame = self.frame;
        targetFrame.origin.y -= CGRectGetHeight(targetFrame);
        self.frame = targetFrame;
    }];
}

- (void)didTapHalfBlackView:(UITapGestureRecognizer *)tap
{
    if (tap.state != UIGestureRecognizerStateEnded) return;
    [self.delegate jumpToPageSheet:self didSelectPage:AwfulThreadPageNone];
    [self dismiss];
}

- (void)showFromView:(UIView *)view
{
    if (!self.popover) {
        UIViewController *content = [UIViewController new];
        content.view = self;
        self.popover = [[UIPopoverController alloc] initWithContentViewController:content];
        self.popover.delegate = self;
        self.popover.popoverContentSize = self.frame.size;
    }
    [self.popover presentPopoverFromRect:view.bounds inView:view
                permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void)dismiss
{
    if (self.popover) {
        [self.popover dismissPopoverAnimated:NO];
        self.popover = nil;
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            self.halfBlackView.alpha = 0;
            CGRect targetFrame = self.frame;
            targetFrame.origin.y += CGRectGetHeight(targetFrame);
            self.frame = targetFrame;
        } completion:^(BOOL finished) {
            [self.halfBlackView removeFromSuperview];
            [self removeFromSuperview];
        }];
    }
}

#pragma mark - UIPickerViewDataSource and UIPickerViewDelegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return [self.delegate numberOfPagesInJumpToPageSheet:self];
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    return [@(row + 1) stringValue];
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    [self.delegate jumpToPageSheet:self didSelectPage:AwfulThreadPageNone];
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithDelegate:nil];
}

- (void)layoutSubviews
{
    CGRect topBarFrame, pickerFrame;
    const CGFloat toolbarHeight = 38;
    CGRectDivide(self.bounds, &topBarFrame, &pickerFrame, toolbarHeight, CGRectMinYEdge);
    self.topBar.frame = topBarFrame;
    self.pickerView.frame = pickerFrame;
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
