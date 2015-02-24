//  AwfulThreadTagPickerController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagPickerController.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulNewThreadTagObserver.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulThreadTagPickerCell.h"
#import "AwfulThreadTagPickerLayout.h"
#import "Awful-Swift.h"

@interface AwfulThreadTagPickerController () <UICollectionViewDelegateFlowLayout, UIPopoverControllerDelegate>

@property (strong, nonatomic) UIPopoverController *popover;
@property (weak, nonatomic) UIView *presentingView;

@property (readonly, strong, nonatomic) NSMutableDictionary *threadTagObservers;

@end

@implementation AwfulThreadTagPickerController

@synthesize cancelButtonItem = _cancelButtonItem;
@synthesize doneButtonItem = _doneButtonItem;
@synthesize threadTagObservers = _threadTagObservers;

- (instancetype)initWithImageNames:(NSArray *)imageNames secondaryImageNames:(NSArray *)secondaryImageNames
{
    AwfulThreadTagPickerLayout *layout = [AwfulThreadTagPickerLayout new];
    layout.itemSize = CGSizeMake(60, 60);
    layout.minimumInteritemSpacing = 5;
    layout.minimumLineSpacing = 5;
    if ((self = [super initWithCollectionViewLayout:layout])) {
        _imageNames = [imageNames copy];
        _secondaryImageNames = [secondaryImageNames copy];
        
        self.title = @"Choose Post Icon";
        self.clearsSelectionOnViewWillAppear = NO;
        self.collectionView.allowsMultipleSelection = secondaryImageNames.count > 0;
    }
    return self;
}

- (UIBarButtonItem *)cancelButtonItem
{
    if (_cancelButtonItem) return _cancelButtonItem;
    _cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:nil action:nil];
    __weak __typeof__(self) weakSelf = self;
    _cancelButtonItem.awful_actionBlock = ^(UIBarButtonItem *item) {
        __typeof__(self) self = weakSelf;
        [self dismiss];
        if ([self.delegate respondsToSelector:@selector(threadTagPickerDidDismiss:)]) {
            [self.delegate threadTagPickerDidDismiss:self];
        }
    };
    return _cancelButtonItem;
}

- (UIBarButtonItem *)doneButtonItem
{
    if (_doneButtonItem) return _doneButtonItem;
    _doneButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:nil action:nil];
    __weak __typeof__(self) weakSelf = self;
    _doneButtonItem.awful_actionBlock = ^(UIBarButtonItem *item) {
        __typeof__(self) self = weakSelf;
        [self dismiss];
        if ([self.delegate respondsToSelector:@selector(threadTagPickerDidDismiss:)]) {
            [self.delegate threadTagPickerDidDismiss:self];
        }
    };
    return _doneButtonItem;
}

- (NSMutableDictionary *)threadTagObservers
{
    if (!_threadTagObservers) _threadTagObservers = [NSMutableDictionary new];
    return _threadTagObservers;
}

- (void)loadView
{
    [super loadView];
    [self.collectionView registerClass:[AwfulThreadTagPickerCell class] forCellWithReuseIdentifier:CellIdentifier];
    [self.collectionView registerClass:[AwfulSecondaryTagPickerCell class] forCellWithReuseIdentifier:SecondaryCellIdentifier];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        const CGFloat popoverCornerRadius = 10;
        self.collectionView.contentInset = UIEdgeInsetsMake(popoverCornerRadius, 0, popoverCornerRadius, 0);
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.view.backgroundColor = self.theme[@"tagPickerBackgroundColor"];
}

- (void)presentFromView:(UIView *)view
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.popover = [[UIPopoverController alloc] initWithContentViewController:self];
        self.popover.delegate = self;
        self.presentingView = view;
        UIPopoverArrowDirection arrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
        [self.popover presentPopoverFromRect:view.bounds inView:view permittedArrowDirections:arrowDirections animated:YES];
    } else {
        [view.awful_viewController presentViewController:[self enclosingNavigationController] animated:YES completion:nil];
    }
}

- (void)dismiss
{
    if (self.popover) {
        [self.popover dismissPopoverAnimated:YES];
        self.popover = nil;
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)selectImageName:(NSString *)imageName
{
    NSUInteger item = [self.imageNames indexOfObject:imageName];
    if (item != NSNotFound) {
        NSInteger section = self.secondaryImageNames.count > 0 ? 1 : 0;
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
        [self.collectionView performBatchUpdates:^{
            [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionTop];
            [self ensureLoneSelectedCellInSectionAtIndexPath:indexPath];
        } completion:nil];
    }
}

- (void)selectSecondaryImageName:(NSString *)imageName
{
    NSAssert(self.secondaryImageNames.count > 0, @"Thread tag picker must be showing secondary thread tags to select one");
    
    NSUInteger item = [self.secondaryImageNames indexOfObject:imageName];
    if (item != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:0];
        [self.collectionView performBatchUpdates:^{
            [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionTop];
            [self ensureLoneSelectedCellInSectionAtIndexPath:indexPath];
        } completion:nil];
    }
}

- (void)ensureLoneSelectedCellInSectionAtIndexPath:(NSIndexPath *)indexPath
{
    for (NSIndexPath *selectedIndexPath in [self.collectionView indexPathsForSelectedItems]) {
        if (selectedIndexPath.section == indexPath.section && selectedIndexPath.item != indexPath.item) {
            [self.collectionView deselectItemAtIndexPath:selectedIndexPath animated:YES];
        }
    }
}

- (BOOL)sectionIsForSecondaryThreadTags:(NSInteger)index
{
    return self.secondaryImageNames.count > 0 && index == 0;
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
    *view = self.presentingView;
    *rect = (*view).bounds;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popover = nil;
    if ([self.delegate respondsToSelector:@selector(threadTagPickerDidDismiss:)]) {
        [self.delegate threadTagPickerDidDismiss:self];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    if (self.secondaryImageNames.count > 0) {
        return 2;
    } else {
        return 1;
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if ([self sectionIsForSecondaryThreadTags:section]) {
        return self.secondaryImageNames.count;
    } else {
        return self.imageNames.count;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self sectionIsForSecondaryThreadTags:indexPath.section]) {
        AwfulSecondaryTagPickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:SecondaryCellIdentifier forIndexPath:indexPath];
        
        cell.titleTextColor = self.theme[@"tagPickerTextColor"];
        cell.tagImageName = self.secondaryImageNames[indexPath.item];
        
        return cell;
    } else {
        AwfulThreadTagPickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
        NSInteger item = indexPath.item;
        NSString *imageName = self.imageNames[item];
        UIImage *image = [AwfulThreadTagLoader imageNamed:imageName];
        cell.image = image;
        
        if (image) {
            cell.tagImageName = nil;
        } else {
            cell.tagImageName = [imageName stringByDeletingPathExtension];
            self.threadTagObservers[@(item)] = [[AwfulNewThreadTagObserver alloc] initWithImageName:imageName downloadedBlock:^(UIImage *image) {
                
                // Make sure the cell still refers to the same tag before changing its image.
                NSIndexPath *currentIndexPath = [collectionView indexPathForCell:cell];
                if (currentIndexPath && currentIndexPath.item == item) {
                    cell.image = image;
                    cell.tagImageName = nil;
                }
                [self.threadTagObservers removeObjectForKey:@(item)];
            }];
        }
        
        return cell;
    }
}

static NSString * const CellIdentifier = @"Cell";
static NSString * const SecondaryCellIdentifier = @"Secondary";

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.collectionView performBatchUpdates:^{
        [self ensureLoneSelectedCellInSectionAtIndexPath:indexPath];
    } completion:nil];

    if ([self sectionIsForSecondaryThreadTags:indexPath.section]) {
        [self.delegate threadTagPicker:self didSelectSecondaryImageName:self.secondaryImageNames[indexPath.item]];
    } else {
        [self.delegate threadTagPicker:self didSelectImageName:self.imageNames[indexPath.item]];
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if ([self sectionIsForSecondaryThreadTags:section]) {
        insets.bottom = 15;
    }
    return insets;
}

@end
