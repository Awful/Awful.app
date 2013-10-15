//  AwfulIconActionSheet.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulIconActionSheet.h"
#import "AwfulIconActionCell.h"
#import "AwfulIconActionItem.h"
#import "AwfulPopoverBackgroundView.h"
#import "AwfulTheme.h"

@interface AwfulIconActionSheet () <UICollectionViewDataSource, UICollectionViewDelegate, UIPopoverControllerDelegate>

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
    UIView *_overlay;
    UIPopoverController *_popover;
    NSLayoutConstraint *_gridHeightConstraint;
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _items = [NSMutableArray new];
    
    if ([self needsOwnBlurryBackground]) {
        _toolbar = [UIToolbar new];
        _toolbar.translatesAutoresizingMaskIntoConstraints = NO;
        _toolbar.barTintColor = [AwfulTheme.currentTheme[@"actionSheetBackgroundColor"] colorWithAlphaComponent:1];
        [self addSubview:_toolbar];
    }
    
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

- (BOOL)needsOwnBlurryBackground
{
    return UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad;
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
                             @"grid": _collectionView };
    NSDictionary *metrics = @{ @"margin": @10 };
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-margin-[title]-[topDivider(==1)]-[grid]"
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
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:[grid]-[bottomDivider(==1)]-[cancel]-margin-|"
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
    if ([self needsOwnBlurryBackground]) {
        NSDictionary *extraViews = @{ @"background": _toolbar };
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[background]|"
                                                 options:0
                                                 metrics:nil
                                                   views:extraViews]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[background]|"
                                                 options:0
                                                 metrics:nil
                                                   views:extraViews]];
    }
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
    if ([self showsInPopover]) {
        [self createAndConfigurePopover];
        [_popover presentPopoverFromRect:rect
                                  inView:view
                permittedArrowDirections:UIPopoverArrowDirectionAny
                                animated:animated];
    } else {
        [self showInView:view animated:animated];
    }
}

- (void)showFromBarButtonItem:(UIBarButtonItem *)barButtonItem animated:(BOOL)animated
{
    if ([self showsInPopover]) {
        [self createAndConfigurePopover];
        [_popover presentPopoverFromBarButtonItem:barButtonItem
                         permittedArrowDirections:UIPopoverArrowDirectionAny
                                         animated:animated];
    } else {
        [self showInView:[barButtonItem valueForKeyPath:@"view.superview.superview"] animated:animated];
    }
}

- (void)showInView:(UIView *)view animated:(BOOL)animated
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.layer.cornerRadius = 5;
    self.clipsToBounds = YES;
    UIView *overlay = [UIView new];
    _overlay = overlay;
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:self];
    [view.window addSubview:overlay];
    [view.window addConstraint:
     [NSLayoutConstraint constraintWithItem:self
                                  attribute:NSLayoutAttributeLeft
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:view
                                  attribute:NSLayoutAttributeLeft
                                 multiplier:1
                                   constant:LeftRightMargin]];
    [view.window addConstraint:
     [NSLayoutConstraint constraintWithItem:self
                                  attribute:NSLayoutAttributeRight
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:view
                                  attribute:NSLayoutAttributeRight
                                 multiplier:1
                                   constant:-LeftRightMargin]];
    [view.window addConstraint:
     [NSLayoutConstraint constraintWithItem:_collectionView
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:view
                                  attribute:NSLayoutAttributeCenterY
                                 multiplier:1
                                   constant:0]];
    NSDictionary *views = @{ @"overlay": overlay };
    [view.window addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[overlay]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [view.window addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[overlay]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
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
    contentViewController.preferredContentSize = [self systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    _popover = [[UIPopoverController alloc] initWithContentViewController:contentViewController];
    _popover.popoverBackgroundViewClass = [AwfulPopoverBackgroundView class];
    _popover.delegate = self;
}

- (void)dismissAnimated:(BOOL)animated
{
    [_overlay removeFromSuperview];
    _overlay = nil;
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
