//  AwfulIconActionSheet.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulIconActionSheet.h"
#import "AwfulIconActionCell.h"
#import "AwfulIconActionItem.h"
#import "AwfulPopoverBackgroundView.h"
#import "AwfulTheme.h"
#import <WYPopoverController/WYPopoverController.h>

@interface AwfulIconActionSheet () <UICollectionViewDataSource, UICollectionViewDelegate, WYPopoverControllerDelegate>

@end

@implementation AwfulIconActionSheet
{
    NSMutableArray *_items;
    UIToolbar *_toolbar;
    UILabel *_titleLabel;
    UIView *_topDivider;
    UICollectionView *_collectionView;
    UIView *_bottomDivider;
    UIButton *_cancelButton;
    WYPopoverController *_popover;
    NSLayoutConstraint *_gridHeightConstraint;
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _items = [NSMutableArray new];
    
    _toolbar = [UIToolbar new];
    _toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    _toolbar.barTintColor = [AwfulTheme.currentTheme[@"actionSheetBackgroundColor"] colorWithAlphaComponent:1];
    [self addSubview:_toolbar];
    
    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                 forAxis:UILayoutConstraintAxisVertical];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.numberOfLines = 0;
    _titleLabel.textColor = [UIColor whiteColor];
    [self addSubview:_titleLabel];
    
    _topDivider = [UIView new];
    _topDivider.translatesAutoresizingMaskIntoConstraints = NO;
    _topDivider.backgroundColor = [UIColor grayColor];
    [self addSubview:_topDivider];
    
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    if ([self onlyShowsOneRowOfIcons]) {
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    } else {
        layout.sectionInset = UIEdgeInsetsMake(0, 20, 0, 20);
    }
    layout.itemSize = CGSizeMake(70, 90);
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [_collectionView registerClass:[AwfulIconActionCell class] forCellWithReuseIdentifier:CellIdentifier];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.backgroundColor = nil;
    _collectionView.showsHorizontalScrollIndicator = NO;
    if ([self onlyShowsOneRowOfIcons]) {
        _collectionView.contentInset = UIEdgeInsetsMake(0, 17, 0, 17);
    }
    [self addSubview:_collectionView];
    
    if ([self needsCancelButton]) {
        _bottomDivider = [UIView new];
        _bottomDivider.translatesAutoresizingMaskIntoConstraints = NO;
        _bottomDivider.backgroundColor = [UIColor grayColor];
        [self addSubview:_bottomDivider];
        
        _cancelButton = [UIButton new];
        _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_cancelButton setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                       forAxis:UILayoutConstraintAxisVertical];
        [_cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
        [_cancelButton addTarget:self action:@selector(didTapCancel) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_cancelButton];
    }
    
    [self setNeedsUpdateConstraints];
    return self;
}

- (void)didTapCancel
{
    [self dismissAnimated:YES];
}

- (BOOL)needsCancelButton
{
    return UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad;
}

- (BOOL)onlyShowsOneRowOfIcons
{
    return UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad;
}

- (BOOL)showsInPopover
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

- (void)updateConstraints
{
    NSDictionary *views = @{ @"title": _titleLabel,
                             @"topDivider": _topDivider,
                             @"grid": _collectionView,
                             @"background": _toolbar };
    NSDictionary *metrics = @{ @"margin": @10 };
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-margin-[title]-14-[topDivider(==1)]-[grid]"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[title]-|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[topDivider]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[grid]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    if ([self needsCancelButton]) {
        NSDictionary *extraViews = @{ @"grid": views[@"grid"],
                                      @"bottomDivider": _bottomDivider,
                                      @"cancel": _cancelButton };
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:[grid]-[bottomDivider(==1)]-8-[cancel]-margin-|"
                                                 options:0
                                                 metrics:metrics
                                                   views:extraViews]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bottomDivider]|"
                                                 options:0
                                                 metrics:nil
                                                   views:extraViews]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[cancel]-|"
                                                 options:0
                                                 metrics:nil
                                                   views:extraViews]];
    } else {
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:[grid]-margin-|"
                                                 options:0
                                                 metrics:metrics
                                                   views:views]];
    }
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[background]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[background]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    if ([self onlyShowsOneRowOfIcons]) {
        UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)_collectionView.collectionViewLayout;
        [_collectionView addConstraint:[NSLayoutConstraint constraintWithItem:_collectionView
                                                                    attribute:NSLayoutAttributeHeight
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:nil
                                                                    attribute:NSLayoutAttributeNotAnAttribute
                                                                   multiplier:1
                                                                     constant:layout.itemSize.height]];
    }
    if ([self showsInPopover]) {
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:self
                                      attribute:NSLayoutAttributeWidth
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:nil
                                      attribute:NSLayoutAttributeNotAnAttribute
                                     multiplier:1
                                       constant:320 - 2 * LeftRightMargin]];
    }
    [super updateConstraints];
}

static const CGFloat LeftRightMargin = 8;

- (NSString *)title
{
    return _titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
}

- (NSArray *)items
{
    return [_items copy];
}

- (void)setItems:(NSArray *)items
{
    [_items setArray:items];
}

- (void)addItem:(AwfulIconActionItem *)item
{
    [_items addObject:item];
}

- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated
{
    [self createAndConfigurePopover];
    if ([self showsInPopover]) {
        [_popover presentPopoverFromRect:rect
                                  inView:view
                permittedArrowDirections:WYPopoverArrowDirectionAny
                                animated:animated];
    } else {
        [_popover presentPopoverAsDialogAnimated:animated];
    }
}

- (void)showFromBarButtonItem:(UIBarButtonItem *)barButtonItem animated:(BOOL)animated
{
    [self createAndConfigurePopover];
    if ([self showsInPopover]) {
        [_popover presentPopoverFromBarButtonItem:barButtonItem
                         permittedArrowDirections:WYPopoverArrowDirectionAny
                                         animated:animated];
    } else {
        [_popover presentPopoverAsDialogAnimated:animated];
    }
}

- (void)createAndConfigurePopover
{
    UIViewController *contentViewController = [UIViewController new];
    contentViewController.view = self;
    
    // Lay out now so we can get the collection view's content size.
    [self layoutIfNeeded];
    
    UICollectionViewLayout *layout = _collectionView.collectionViewLayout;
    _gridHeightConstraint = [NSLayoutConstraint constraintWithItem:_collectionView
                                                         attribute:NSLayoutAttributeHeight
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:nil
                                                         attribute:NSLayoutAttributeNotAnAttribute
                                                        multiplier:1
                                                          constant:layout.collectionViewContentSize.height];
    [_collectionView addConstraint:_gridHeightConstraint];
    CGSize contentSize = [self systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    if (contentSize.width < 312) {
        contentSize.width = 312;
    }
    contentViewController.preferredContentSize = contentSize;
    _popover = [[WYPopoverController alloc] initWithContentViewController:contentViewController];
    _popover.delegate = self;
}

- (void)dismissAnimated:(BOOL)animated
{
    [_popover dismissPopoverAnimated:animated];
    _popover = nil;
    [_collectionView removeConstraint:_gridHeightConstraint];
    _gridHeightConstraint = nil;
}

#pragma mark - UICollectionViewDataSource and UICollectionViewDelegate

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulIconActionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier
                                                                          forIndexPath:indexPath];
    AwfulIconActionItem *item = _items[indexPath.item];
    cell.title = item.title;
    cell.icon = item.icon;
    cell.tintColor = item.tintColor;
    cell.isAccessibilityElement = YES;
    cell.accessibilityLabel = item.title;
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    return cell;
}

static NSString * const CellIdentifier = @"IconActionCell";

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulIconActionItem *item = _items[indexPath.item];
    if (item.action) item.action();
    [self dismissAnimated:NO];
}

#pragma mark - UIPopoverControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    [self dismissAnimated:NO];
    return NO;
}

@end
