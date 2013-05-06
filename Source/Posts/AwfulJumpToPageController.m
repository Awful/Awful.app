//
//  AwfulJumpToPageController.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulJumpToPageController.h"

@interface SpecificTopBarView : UIView

@property (weak, nonatomic) UIButton *jumpButton;

@end


@interface AwfulJumpToPageController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (weak, nonatomic) UIPickerView *picker;

@end


@implementation AwfulJumpToPageController

- (instancetype)initWithDelegate:(id <AwfulJumpToPageControllerDelegate>)delegate
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return self;
    self.delegate = delegate;
    self.numberOfPages = 1;
    self.selectedPage = 1;
    return self;
}

#pragma mark - AwfulSemiModalViewController

- (void)presentFromViewController:(UIViewController *)viewController
                         fromRect:(CGRect)rect
                           inView:(UIView *)view
{
    [self.picker selectRow:self.selectedPage - 1 inComponent:0 animated:NO];
    [super presentFromViewController:viewController fromRect:rect inView:view];
}

- (UIPickerView *)picker
{
    if (!_picker) {
        [self view];
    }
    return _picker;
}

- (void)userDismiss
{
    [self.delegate jumpToPageController:self didSelectPage:AwfulThreadPageNone];
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithDelegate:nil];
}

- (void)loadView
{
    // UIPickerView is rather picky (lol) about its height. Make sure you pick a value it likes.
    const CGFloat pickerHeight = 162;
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


- (void)didTapJumpToPage
{
    [self.delegate jumpToPageController:self didSelectPage:self.selectedPage];
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
    CGRect buttonFrame = self.jumpButton.frame;
    buttonFrame.size.width = 115;
    buttonFrame.size.height = 29;
    buttonFrame.origin.x = self.bounds.size.width - buttonFrame.size.width - 7;
    self.jumpButton.frame = buttonFrame;
    self.jumpButton.center = CGPointMake(self.jumpButton.center.x, CGRectGetMidY(self.bounds));
    self.jumpButton.frame = CGRectIntegral(self.jumpButton.frame);
}

@end
