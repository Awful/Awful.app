//
//  AwfulPostIconPickerController.m
//  Awful
//
//  Created by Nolan Waite on 2013-03-04.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostIconPickerController.h"
#import "AwfulImageCollectionViewCell.h"
#import "AwfulTheme.h"
#import "AwfulThreadTags.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPostIconPickerController () <UIPopoverControllerDelegate>

@property (nonatomic) NSInteger numberOfIcons;

@property (nonatomic) UIBarButtonItem *pickButtonItem;
@property (nonatomic) UIBarButtonItem *cancelButtonItem;

@property (nonatomic) UIPopoverController *popover;

@end


@implementation AwfulPostIconPickerController

- (instancetype)initWithDelegate:(id <AwfulPostIconPickerControllerDelegate>)delegate
{
    PSUICollectionViewFlowLayout *layout = [PSUICollectionViewFlowLayout new];
    layout.itemSize = CGSizeMake(47, 47);
    layout.minimumInteritemSpacing = 15;
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
    if ([selectedItems count] == 0) {
        return NSNotFound;
    }
    NSIndexPath *indexPath = selectedItems[0];
    return indexPath.item;
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:selectedIndex inSection:0];
    PSTCollectionViewScrollPosition scroll = PSTCollectionViewScrollPositionCenteredVertically;
    [self.collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:scroll];
}

#pragma mark - PSUICollectionViewDataSource and PSUICollectionViewDelegate

- (NSInteger)collectionView:(PSTCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
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
    cell.imageView.image = [self.delegate postIconPicker:self postIconAtIndex:indexPath.item];
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

- (void)collectionView:(PSTCollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.delegate respondsToSelector:@selector(postIconPicker:didSelectIconAtIndex:)]) {
        [self.delegate postIconPicker:self didSelectIconAtIndex:indexPath.item];
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.collectionView.backgroundColor = [AwfulTheme currentTheme].postIconPickerBackgroundColor;
    [self.collectionView registerClass:[AwfulImageCollectionViewCell class]
            forCellWithReuseIdentifier:TagCellIdentifier];
    [self reloadData];
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popover = nil;
}

@end
