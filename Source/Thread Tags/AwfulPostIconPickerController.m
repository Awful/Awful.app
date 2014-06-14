//  AwfulPostIconPickerController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostIconPickerController.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulImageCollectionViewCell.h"
#import "AwfulSecondaryTagCollectionViewCell.h"

@interface AwfulPostIconPickerController () <UIPopoverControllerDelegate>

@property (nonatomic) NSInteger numberOfIcons;
@property (nonatomic) NSInteger numberOfSecondaryIcons;

@property (nonatomic) UIBarButtonItem *pickButtonItem;
@property (nonatomic) UIBarButtonItem *cancelButtonItem;

@property (nonatomic) UIPopoverController *popover;

@property (nonatomic) UICollectionView *secondaryIconPicker;

@end


static const CGFloat kSecondaryPickerVMargin = 12;
static const CGFloat kCollectionViewItemWidth = 60;
static const CGFloat kCollectionViewItemHeight = 60;
static const CGFloat kSecondaryCollectionViewItemHeight = 74;
static const CGFloat kCollectionViewSpacing = 5;

@interface AwfulPostIconPickerController () <UICollectionViewDelegateFlowLayout>
@end


@implementation AwfulPostIconPickerController
{
    NSInteger _selectedIndex;
    NSInteger _selectedSecondaryIndex;
}

- (instancetype)initWithDelegate:(id <AwfulPostIconPickerControllerDelegate>)delegate
{
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.itemSize = CGSizeMake(kCollectionViewItemWidth, kCollectionViewItemHeight);
    layout.minimumInteritemSpacing = kCollectionViewSpacing;
    layout.minimumLineSpacing = kCollectionViewSpacing;
    if (!(self = [super initWithCollectionViewLayout:layout])) return nil;
    _delegate = delegate;
    self.clearsSelectionOnViewWillAppear = NO;
    self.title = @"Choose Post Icon";
    self.navigationItem.leftBarButtonItem = self.cancelButtonItem;
    
    UICollectionViewFlowLayout *secondaryLayout = [UICollectionViewFlowLayout new];
    secondaryLayout.itemSize = CGSizeMake(kCollectionViewItemWidth, kSecondaryCollectionViewItemHeight);
    secondaryLayout.minimumInteritemSpacing = kCollectionViewSpacing;
    secondaryLayout.minimumLineSpacing = kCollectionViewSpacing;
    self.secondaryIconPicker = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:secondaryLayout];
    self.secondaryIconPicker.delegate = self;
    self.secondaryIconPicker.dataSource = self;
    self.secondaryIconPicker.backgroundColor = self.theme[@"collectionViewBackgroundColor"];
    self.secondaryIconPicker.scrollEnabled = NO;
    [self.secondaryIconPicker registerClass:[AwfulSecondaryTagCollectionViewCell class] forCellWithReuseIdentifier:SecondaryCellIdentifier];
    [self.view addSubview:self.secondaryIconPicker];
    
    return self;
}

- (void)themeDidChange
{
	[super themeDidChange];
    AwfulTheme *theme = self.theme;
    self.secondaryIconPicker.backgroundColor = theme[@"collectionViewBackgroundColor"];
    [self.secondaryIconPicker reloadData];
}

static NSString * const TagCellIdentifier = @"Tag Cell";
static NSString * const SecondaryCellIdentifier = @"Secondary Tag Cell";

- (UIBarButtonItem *)cancelButtonItem
{
    if (_cancelButtonItem) return _cancelButtonItem;
    _cancelButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                         style:UIBarButtonItemStyleBordered
                                                        target:self action:@selector(didTapCancel)];
    return _cancelButtonItem;
}

- (void)didTapCancel
{
    if ([self.delegate respondsToSelector:@selector(postIconPickerDidCancel:)]) {
        [self.delegate postIconPickerDidCancel:self];
    }
}

- (void)reloadData
{
    self.numberOfIcons = [self.delegate numberOfIconsInPostIconPicker:self];
    if ([self.delegate respondsToSelector:@selector(numberOfSecondaryIconsInPostIconPicker:)]) {
        self.numberOfSecondaryIcons = [self.delegate numberOfSecondaryIconsInPostIconPicker:self];
    } else {
        self.numberOfSecondaryIcons = 0;
    }
    [self.collectionView reloadData];
    
    if (self.numberOfSecondaryIcons == 0) {
        self.collectionView.contentInset = UIEdgeInsetsZero;
        self.secondaryIconPicker.hidden = YES;
    } else {
        const CGFloat kSecondaryPickerHeight = kSecondaryCollectionViewItemHeight + (kSecondaryPickerVMargin * 2);
        self.secondaryIconPicker.frame = CGRectMake(0, 0, self.collectionView.frame.size.width, kSecondaryPickerHeight);
        self.collectionView.contentInset = UIEdgeInsetsMake(kSecondaryPickerHeight, 0, 0, 0);
        self.secondaryIconPicker.hidden = NO;
        [self.secondaryIconPicker reloadData];
    }
    
    self.selectedIndex = _selectedIndex;
    self.secondarySelectedIndex = _selectedSecondaryIndex;
}

- (void)showFromRect:(CGRect)rect inView:(UIView *)view
{
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) return;
    if (!self.popover) {
        self.popover = [[AwfulPopoverController alloc] initWithContentViewController:self];
        self.popover.delegate = self;
    }
    [self.popover presentPopoverFromRect:rect inView:view
                permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)dismiss
{
    [self.popover dismissPopoverAnimated:YES];
    self.popover = nil;
}

- (NSInteger)selectedIndex
{
    NSArray *selectedItems = [self.collectionView indexPathsForSelectedItems];
    if ([selectedItems count] == 1) {
        NSIndexPath *indexPath = selectedItems[0];
        return indexPath.item;
    }
    return NSNotFound;
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    _selectedIndex = selectedIndex;
    NSInteger section = 0;
    UICollectionViewScrollPosition scroll = UICollectionViewScrollPositionCenteredVertically;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems]) {
        if (indexPath.section == section) {
            [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
        }
    }
    if (selectedIndex >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:selectedIndex inSection:section];
        [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:scroll];
    }
}

- (NSInteger)secondarySelectedIndex
{
    if (self.numberOfSecondaryIcons == 0) return NSNotFound;
    for (NSIndexPath *indexPath in [self.secondaryIconPicker indexPathsForSelectedItems]) {
        if (indexPath.section == 0) return indexPath.item;
    }
    return NSNotFound;
}

- (void)setSecondarySelectedIndex:(NSInteger)secondarySelectedIndex
{
    if (self.numberOfSecondaryIcons == 0) return;
    _selectedSecondaryIndex = secondarySelectedIndex;
    NSInteger section = 0;
    UICollectionViewScrollPosition scroll = UICollectionViewScrollPositionNone;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems]) {
        if (indexPath.section == section) {
            [self.secondaryIconPicker deselectItemAtIndexPath:indexPath animated:NO];
        }
    }
    if (secondarySelectedIndex >= -1) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:secondarySelectedIndex inSection:section];
        [self.secondaryIconPicker selectItemAtIndexPath:indexPath animated:NO scrollPosition:scroll];
    }
}

- (UIImage *)selectedIconImage
{
    NSInteger section = 0;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems]) {
        if (indexPath.section == section) {
            return [self.delegate postIconPicker:self postIconAtIndex:indexPath.item];
        }
    }
    return nil;
}

#pragma mark - UICollectionViewDataSource and UICollectionViewDelegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    if (collectionView == self.secondaryIconPicker) {
        return self.numberOfSecondaryIcons;
    }
    return self.numberOfIcons;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = nil;
    if (collectionView == self.secondaryIconPicker) {
        AwfulSecondaryTagCollectionViewCell *awfulCell = [collectionView dequeueReusableCellWithReuseIdentifier:SecondaryCellIdentifier
                                                                                                   forIndexPath:indexPath];
        awfulCell.tagImageName = [self.delegate postIconPicker:self nameOfSecondaryIconAtIndex:indexPath.item];
        awfulCell.titleTextColor = self.theme[@"collectionViewTextColor"];
        cell = awfulCell;
    } else {
        AwfulImageCollectionViewCell *awfulCell = [collectionView dequeueReusableCellWithReuseIdentifier:TagCellIdentifier forIndexPath:indexPath];
        awfulCell.icon = [self.delegate postIconPicker:self postIconAtIndex:indexPath.item];
        cell = awfulCell;
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    for (NSIndexPath *selected in [collectionView indexPathsForSelectedItems]) {
        if (selected.section == indexPath.section && selected.item != indexPath.item) {
            [collectionView deselectItemAtIndexPath:selected animated:NO];
        }
    }
    
    if (collectionView == self.secondaryIconPicker) {
        SEL selector = @selector(postIconPicker:didSelectSecondaryIconAtIndex:);
        if ([self.delegate respondsToSelector:selector]) {
            [self.delegate postIconPicker:self didSelectSecondaryIconAtIndex:indexPath.item];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(postIconPicker:didSelectIconAtIndex:)]) {
            [self.delegate postIconPicker:self didSelectIconAtIndex:indexPath.item];
        }
    }
    
    if (self.numberOfSecondaryIcons == 0 || (self.selectedIndex != NSNotFound && self.secondarySelectedIndex != NSNotFound)) {
        if ([self.delegate respondsToSelector:@selector(postIconPickerDidComplete:)]) {
            [self.delegate postIconPickerDidComplete:self];
        }
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section
{
    if (collectionView == self.secondaryIconPicker) {
        CGFloat totalWidth = (self.numberOfSecondaryIcons * (kCollectionViewItemWidth + kCollectionViewSpacing)) - kCollectionViewSpacing;
        CGFloat hMargin = (self.secondaryIconPicker.frame.size.width - totalWidth) / 2;
        return UIEdgeInsetsMake(kSecondaryPickerVMargin, hMargin, kSecondaryPickerVMargin, hMargin);
    }
    return UIEdgeInsetsZero;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.collectionView registerClass:[AwfulImageCollectionViewCell class]
            forCellWithReuseIdentifier:TagCellIdentifier];
    self.collectionView.allowsMultipleSelection = YES;
    [self reloadData];
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popover = nil;
}

@end
