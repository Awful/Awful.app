//  AwfulJumpToPageController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulJumpToPageController.h"
#import "AwfulJumpToPageView.h"

@interface AwfulJumpToPageController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (readonly, strong, nonatomic) AwfulJumpToPageView *jumpToPageView;

@end

@implementation AwfulJumpToPageController

- (id)initWithPostsViewController:(AwfulPostsViewController *)postsViewController
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _postsViewController = postsViewController;
    return self;
}

- (AwfulJumpToPageView *)jumpToPageView
{
    return (AwfulJumpToPageView *)self.view;
}

- (CGSize)preferredContentSize
{
    return self.jumpToPageView.intrinsicContentSize;
}

- (void)loadView
{
    AwfulJumpToPageView *jumpToPageView = [AwfulJumpToPageView new];
    self.view = jumpToPageView;
    
    [jumpToPageView.firstPageButton addTarget:self action:@selector(didTapFirstPageButton) forControlEvents:UIControlEventTouchUpInside];
    [jumpToPageView.jumpButton addTarget:self action:@selector(didTapJumpButton) forControlEvents:UIControlEventTouchUpInside];
    [jumpToPageView.lastPageButton addTarget:self action:@selector(didTapLastPageButton) forControlEvents:UIControlEventTouchUpInside];
    
    jumpToPageView.pickerView.dataSource = self;
    jumpToPageView.pickerView.delegate = self;
}

- (void)themeDidChange
{
    [super themeDidChange];
    AwfulTheme *theme = self.theme;
    self.jumpToPageView.backgroundColor = theme[@"backgroundColor"];
    [self.jumpToPageView.firstPageButton setTitleColor:theme[@"tintColor"] forState:UIControlStateNormal];
    [self.jumpToPageView.jumpButton setTitleColor:theme[@"tintColor"] forState:UIControlStateNormal];
    [self.jumpToPageView.lastPageButton setTitleColor:theme[@"tintColor"] forState:UIControlStateNormal];
    [self.jumpToPageView.pickerView reloadAllComponents];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    AwfulThreadPage currentPage = self.postsViewController.page;
    if (currentPage < 0) {
        currentPage = self.postsViewController.relevantNumberOfPagesInThread;
    }
    [self.jumpToPageView.pickerView selectRow:currentPage - 1 inComponent:0 animated:NO];
    [self updateJumpButtonTitle];
}

- (void)didTapFirstPageButton
{
    self.postsViewController.page = 1;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didTapJumpButton
{
    AwfulThreadPage page = [self.jumpToPageView.pickerView selectedRowInComponent:0] + 1;
    self.postsViewController.page = page;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didTapLastPageButton
{
    self.postsViewController.page = AwfulThreadPageLast;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateJumpButtonTitle
{
    AwfulThreadPage selectedPage = [self.jumpToPageView.pickerView selectedRowInComponent:0] + 1;
    if (selectedPage == self.postsViewController.page) {
        [self.jumpToPageView.jumpButton setTitle:@"Reload" forState:UIControlStateNormal];
    } else {
        [self.jumpToPageView.jumpButton setTitle:@"Jump" forState:UIControlStateNormal];
    }
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.postsViewController.relevantNumberOfPagesInThread;
}

#pragma mark - UIPickerViewDelegate

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView
             attributedTitleForRow:(NSInteger)row
                      forComponent:(NSInteger)component
{
    NSDictionary *attributes = @{ NSForegroundColorAttributeName: self.theme[@"listTextColor"] };
    return [[NSAttributedString alloc] initWithString:[@(row + 1) stringValue] attributes:attributes];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    [self updateJumpButtonTitle];
}

@end
