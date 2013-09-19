//  AwfulJumpToPageController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulJumpToPageController.h"

@interface AwfulJumpToPageController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (strong, nonatomic) UIPickerView *picker;
@property (strong, nonatomic) UIBarButtonItem *firstPageItem;
@property (strong, nonatomic) UIBarButtonItem *lastPageItem;
@property (strong, nonatomic) UIBarButtonItem *jumpToPageItem;

@end

@implementation AwfulJumpToPageController

- (id)initWithDelegate:(id <AwfulJumpToPageControllerDelegate>)delegate
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return self;
    _delegate = delegate;
    _numberOfPages = 1;
    _selectedPage = 1;
    self.navigationItem.leftBarButtonItems = @[ self.firstPageItem, self.lastPageItem ];
    self.navigationItem.rightBarButtonItem = self.jumpToPageItem;
    return self;
}

- (UIBarButtonItem *)firstPageItem
{
    if (_firstPageItem) return _firstPageItem;
    _firstPageItem = [[UIBarButtonItem alloc] initWithTitle:@"First"
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(didTapFirstPage)];
    return _firstPageItem;
}

- (void)didTapFirstPage
{
    [self.delegate jumpToPageController:self didSelectPage:1];
}

- (UIBarButtonItem *)lastPageItem
{
    if (_lastPageItem) return _lastPageItem;
    _lastPageItem = [[UIBarButtonItem alloc] initWithTitle:@"Last"
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(didTapLastPage)];
    _lastPageItem.possibleTitles = [NSSet setWithObject:@"First"];
    return _lastPageItem;
}

- (void)didTapLastPage
{
    [self.delegate jumpToPageController:self didSelectPage:AwfulThreadPageLast];
}

- (UIBarButtonItem *)jumpToPageItem
{
    if (_jumpToPageItem) return _jumpToPageItem;
    _jumpToPageItem = [[UIBarButtonItem alloc] initWithTitle:@"Go"
                                                       style:UIBarButtonItemStyleDone
                                                      target:self
                                                      action:@selector(didTapJumpToPage)];
    return _jumpToPageItem;
}

- (void)didTapJumpToPage
{
    [self.delegate jumpToPageController:self didSelectPage:self.selectedPage];
}

- (CGSize)preferredContentSize
{
    return CGSizeMake(180, pickerHeight);
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
    self.view = [UIView new];
    self.view.backgroundColor = [UIColor whiteColor];
    self.picker = [UIPickerView new];
    self.picker.translatesAutoresizingMaskIntoConstraints = NO;
    self.picker.dataSource = self;
    self.picker.delegate = self;
    self.picker.showsSelectionIndicator = YES;
    [self.view addSubview:self.picker];
    NSDictionary *views = @{ @"picker": self.picker };
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[picker]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[picker]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.118 green:0.518 blue:0.686 alpha:1];
}

// UIPickerView is rather picky (lol) about its height. Make sure you pick a value it likes.
const CGFloat pickerHeight = 162;

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
