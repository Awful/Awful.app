//
//  AwfulJumpToPageController.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulJumpToPageController.h"
#import "AwfulPageBarBackgroundView.h"

@interface SpecificTopBarView : AwfulPageBarBackgroundView

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
    self.contentSizeForViewInPopover = CGSizeMake(180, 38 + pickerHeight);
    return self;
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
    
    UIButton *jumpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    jumpButton.frame = CGRectMake(0, 0, 110, 29);
    [jumpButton setTitle:@"Jump to Page" forState:UIControlStateNormal];
    UIImage *button = [[UIImage imageNamed:@"pagebar-button.png"]
                       resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    [jumpButton setBackgroundImage:button forState:UIControlStateNormal];
    UIImage *selected = [[UIImage imageNamed:@"pagebar-button-selected.png"]
                         resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    [jumpButton setBackgroundImage:selected forState:UIControlStateSelected];
    jumpButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self addSubview:jumpButton];
    _jumpButton = jumpButton;
    return self;
}

- (void)layoutSubviews
{
    self.jumpButton.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}

@end
