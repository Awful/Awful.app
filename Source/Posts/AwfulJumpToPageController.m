//  AwfulJumpToPageController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulJumpToPageController.h"
#import "AwfulPageBarBackgroundView.h"

@interface SpecificTopBarView : AwfulPageBarBackgroundView

@property (weak, nonatomic) UISegmentedControl *firstLastControl;
@property (weak, nonatomic) UIButton *jumpButton;

@end


@interface AwfulJumpToPageController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (weak, nonatomic) UIPickerView *picker;

@end


@implementation AwfulJumpToPageController

- (id)initWithDelegate:(id <AwfulJumpToPageControllerDelegate>)delegate
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return self;
    self.delegate = delegate;
    self.numberOfPages = 1;
    self.selectedPage = 1;
    return self;
}

- (CGSize)preferredContentSize
{
    return CGSizeMake(300, 38 + pickerHeight);
}

- (void)setSelectedPage:(NSInteger)selectedPage
{
    if (_selectedPage == selectedPage) return;
    _selectedPage = selectedPage;
    [self.picker selectRow:selectedPage - 1 inComponent:0 animated:YES];
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithDelegate:nil];
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 38 + pickerHeight)];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    SpecificTopBarView *topBar = [[SpecificTopBarView alloc] initWithFrame:CGRectMake(0, 0, 320, 38)];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [topBar.firstLastControl addTarget:self action:@selector(didTapFirstLastControl:)
                      forControlEvents:UIControlEventValueChanged];
    [topBar.jumpButton addTarget:self action:@selector(didTapJumpToPage)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:topBar];
    UIPickerView *picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 38, 320, pickerHeight)];
    self.picker = picker;
    picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    picker.dataSource = self;
    picker.delegate = self;
    picker.showsSelectionIndicator = YES;
    [self.view addSubview:picker];
}

// UIPickerView is rather picky (lol) about its height. Make sure you pick a value it likes.
const CGFloat pickerHeight = 162;

- (void)didTapFirstLastControl:(UISegmentedControl *)seg
{
    if (seg.selectedSegmentIndex == 0) {
        [self.delegate jumpToPageController:self didSelectPage:1];
    } else if (seg.selectedSegmentIndex == 1) {
        [self.delegate jumpToPageController:self didSelectPage:AwfulThreadPageLast];
    }
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)didTapJumpToPage
{
    [self.delegate jumpToPageController:self didSelectPage:self.selectedPage];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.picker selectRow:self.selectedPage - 1 inComponent:0 animated:NO];
}

#pragma mark - UIPickerViewDataSource and UIPickerViewDelegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.numberOfPages;
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    return [@(row + 1) stringValue];
}

- (void)pickerView:(UIPickerView *)pickerView
      didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component
{
    self.selectedPage = row + 1;
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
    
    NSString *firstPageItem = @"First";
    firstPageItem.accessibilityLabel = @"Jump to first page";
    NSString *lastPageItem = @"Last";
    lastPageItem.accessibilityLabel = @"Jump to last page";
    NSArray *items = @[ firstPageItem, lastPageItem ];
    UISegmentedControl *firstLastControl = [[UISegmentedControl alloc] initWithItems:items];
    firstLastControl.frame = CGRectMake(0, 0, 115, 29);
    CGSize contentOffset = CGSizeMake(0, 1);
    for (NSUInteger i = 0; i < firstLastControl.numberOfSegments; i++) {
        [firstLastControl setContentOffset:contentOffset forSegmentAtIndex:i];
    }
    NSShadow *shadow = [NSShadow new];
    shadow.shadowOffset = CGSizeZero;
    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSShadowAttributeName: shadow
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
    jumpButton.frame = CGRectMake(0, 0, 110, 29);
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
    const CGFloat margin = 8;
    self.firstLastControl.center = CGPointMake(CGRectGetMidX(self.firstLastControl.bounds) + margin,
                                               CGRectGetMidY(self.bounds));
    self.jumpButton.center = CGPointMake(CGRectGetMaxX(self.bounds) -
                                         CGRectGetMidX(self.jumpButton.bounds) - margin,
                                         CGRectGetMidY(self.bounds));
}

@end
