//  AwfulPostIconPickerController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostIconPickerController.h"
#import "AwfulImageCollectionViewCell.h"
#import "AwfulTheme.h"
#import "AwfulThreadTags.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPostIconPickerController () <UIPopoverControllerDelegate>

@property (nonatomic) NSInteger numberOfIcons;
@property (nonatomic) NSInteger numberOfSecondaryIcons;

@property (nonatomic) UIBarButtonItem *pickButtonItem;
@property (nonatomic) UIBarButtonItem *cancelButtonItem;

@property (nonatomic) UIPopoverController *popover;

@end


@implementation AwfulPostIconPickerController

- (instancetype)initWithDelegate:(id <AwfulPostIconPickerControllerDelegate>)delegate
{
    PSUICollectionViewFlowLayout *layout = [PSUICollectionViewFlowLayout new];
    layout.itemSize = CGSizeMake(49, 49);
    layout.minimumInteritemSpacing = 13;
    layout.minimumLineSpacing = 11;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 12, 12);
    if (!(self = [super initWithCollectionViewLayout:layout])) return nil;
    _delegate = delegate;
    self.clearsSelectionOnViewWillAppear = NO;
    self.title = @"Choose Post Icon";
    self.navigationItem.rightBarButtonItem = self.pickButtonItem;
    self.navigationItem.leftBarButtonItem = self.cancelButtonItem;
    return self;
}

static NSString * const TagCellIdentifier = @"Tag Cell";

- (UIBarButtonItem *)pickButtonItem
{
    if (_pickButtonItem) return _pickButtonItem;
    _pickButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Pick" style:UIBarButtonItemStyleDone
                                                      target:self action:@selector(didTapPick)];
    return _pickButtonItem;
}

- (void)didTapPick
{
    if ([self.delegate respondsToSelector:@selector(postIconPickerDidComplete:)]) {
        [self.delegate postIconPickerDidComplete:self];
    }
}

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
}

- (void)showFromRect:(CGRect)rect inView:(UIView *)view
{
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) return;
    if (!self.popover) {
        self.popover = [[UIPopoverController alloc] initWithContentViewController:self];
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
    } else if ([selectedItems count] > 1) {
        for (NSIndexPath *indexPath in selectedItems) {
            if (indexPath.section == 1) {
                return indexPath.item;
            }
        }
    }
    return NSNotFound;
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    NSInteger section = self.numberOfSecondaryIcons > 0 ? 1 : 0;
    PSTCollectionViewScrollPosition scroll = PSTCollectionViewScrollPositionCenteredVertically;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems]) {
        if (indexPath.section == section) {
            [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
        }
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:selectedIndex inSection:section];
    [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:scroll];
    if (self.numberOfSecondaryIcons > 0) [self updateVisibleSecondaryTagCellsIcon];
}

- (NSInteger)secondarySelectedIndex
{
    if (self.numberOfSecondaryIcons == 0) return NSNotFound;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems]) {
        if (indexPath.section == 0) return indexPath.item;
    }
    return NSNotFound;
}

- (void)setSecondarySelectedIndex:(NSInteger)secondarySelectedIndex
{
    if (self.numberOfSecondaryIcons == 0) return;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems]) {
        if (indexPath.section == 0) {
            [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
        }
    }
    NSIndexPath *toSelect = [NSIndexPath indexPathForItem:secondarySelectedIndex inSection:0];
    [self.collectionView selectItemAtIndexPath:toSelect
                                      animated:NO
                                scrollPosition:PSTCollectionViewScrollPositionCenteredVertically];
}

- (void)updateVisibleSecondaryTagCellsIcon
{
    UIImage *selectedIconImage = [self selectedIconImage];
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForVisibleItems]) {
        if (indexPath.section == 0) {
            AwfulImageCollectionViewCell *cell = (id)[self.collectionView cellForItemAtIndexPath:
                                                      indexPath];
            cell.icon = selectedIconImage;
        }
    }
}

- (UIImage *)selectedIconImage
{
    NSInteger section = self.numberOfSecondaryIcons > 0 ? 1 : 0;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems]) {
        if (indexPath.section == section) {
            return [self.delegate postIconPicker:self postIconAtIndex:indexPath.item];
        }
    }
    return nil;
}

#pragma mark - PSUICollectionViewDataSource and PSUICollectionViewDelegate

- (NSInteger)numberOfSectionsInCollectionView:(PSUICollectionView *)collectionView
{
    return self.numberOfSecondaryIcons > 0 ? 2 : 1;
}

- (NSInteger)collectionView:(PSUICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    if (self.numberOfSecondaryIcons > 0 && section == 0) {
        return self.numberOfSecondaryIcons;
    }
    return self.numberOfIcons;
}

- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)collectionView
                    cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulImageCollectionViewCell *cell;
    cell = (id)[collectionView dequeueReusableCellWithReuseIdentifier:TagCellIdentifier
                                                         forIndexPath:indexPath];
    cell.backgroundColor = [UIColor whiteColor];
    cell.layer.cornerRadius = 2;
    cell.layer.shadowOpacity = 0.5;
    cell.layer.shadowOffset = CGSizeZero;
    cell.layer.shadowRadius = 1;
    if (self.numberOfSecondaryIcons > 0 && indexPath.section == 0) {
        cell.icon = [self selectedIconImage];
    } else {
        cell.icon = [self.delegate postIconPicker:self postIconAtIndex:indexPath.item];
    }
    if (self.numberOfSecondaryIcons > 0 && indexPath.section == 0) {
        cell.secondaryIcon = [self.delegate postIconPicker:self
                                      secondaryIconAtIndex:indexPath.item];
    } else {
        cell.secondaryIcon = nil;
    }
    if (!cell.selectedBackgroundView) {
        cell.selectedBackgroundView = [UIView new];
        cell.selectedBackgroundView.layer.cornerRadius = cell.layer.cornerRadius;
        cell.selectedBackgroundView.layer.shadowRadius = 1.5;
        cell.selectedBackgroundView.layer.shadowOpacity = 0.25;
        cell.selectedBackgroundView.layer.shadowOffset = CGSizeZero;
        cell.selectedBackgroundView.backgroundColor = [UIColor colorWithHue:0.526
                                                                 saturation:0.561
                                                                 brightness:1 alpha:1];
    }
    return cell;
}

- (void)collectionView:(PSUICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    for (NSIndexPath *selected in [collectionView indexPathsForSelectedItems]) {
        if (selected.section == indexPath.section && selected.item != indexPath.item) {
            [collectionView deselectItemAtIndexPath:selected animated:NO];
        }
    }
    if (self.numberOfSecondaryIcons > 0 && indexPath.section == 1) {
        [self updateVisibleSecondaryTagCellsIcon];
    }
    if (self.numberOfSecondaryIcons > 0 && indexPath.section == 0) {
        SEL selector = @selector(postIconPicker:didSelectSecondaryIconAtIndex:);
        if ([self.delegate respondsToSelector:selector]) {
            [self.delegate postIconPicker:self didSelectSecondaryIconAtIndex:indexPath.item];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(postIconPicker:didSelectIconAtIndex:)]) {
            [self.delegate postIconPicker:self didSelectIconAtIndex:indexPath.item];
        }
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.collectionView.backgroundColor = [AwfulTheme currentTheme].postIconPickerBackgroundColor;
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
