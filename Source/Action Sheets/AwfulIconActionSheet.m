//  AwfulIconActionSheet.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulIconActionSheet.h"
#import "AwfulIconActionCell.h"
#import "AwfulIconActionItem.h"
#import <PSTCollectionView/PSTCollectionView.h>

@interface AwfulIconActionSheet () <PSUICollectionViewDataSource, PSUICollectionViewDelegate>

@property (nonatomic) NSMutableArray *items;
@property (readonly, nonatomic) PSUICollectionView *collectionView;

@end


@interface AwfulIconActionSheetSectionHeader : PSUICollectionReusableView

@property (copy, nonatomic) NSString *title;
@property (nonatomic) UIEdgeInsets titleInsets;

+ (UIFont *)titleLabelFont;

@end


@implementation AwfulIconActionSheet

- (void)addItem:(AwfulIconActionItem *)item
{
    NSInteger newIndex = [self.items count];
    [self.items addObject:item];
    if ([self isViewLoaded]) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:newIndex inSection:0];
        [self.collectionView insertItemsAtIndexPaths:@[ indexPath ]];
    }
}

- (PSUICollectionView *)collectionView
{
    return (id)self.view;
}

#pragma mark - PSUICollectionViewDataSource and PSUICollectionViewDelegate

- (NSInteger)collectionView:(PSUICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return [self.items count];
}

- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)collectionView
                    cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulIconActionCell *cell;
    cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier
                                                     forIndexPath:indexPath];
    AwfulIconActionItem *item = self.items[indexPath.item];
    cell.title = item.title;
    cell.icon = item.icon;
    cell.tintColor = item.tintColor;
    cell.isAccessibilityElement = YES;
    cell.accessibilityLabel = item.title;
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    return cell;
}

static NSString * const CellIdentifier = @"IconActionCell";

- (PSUICollectionReusableView *)collectionView:(PSUICollectionView *)collectionView
             viewForSupplementaryElementOfKind:(NSString *)kind
                                   atIndexPath:(NSIndexPath *)indexPath
{
    AwfulIconActionSheetSectionHeader *header;
    header = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                withReuseIdentifier:HeaderIdentifier
                                                       forIndexPath:indexPath];
    header.title = self.title;
    header.titleInsets = UIEdgeInsetsMake(0, SectionInsets.left, 0, SectionInsets.right);
    return header;
}

static NSString * const HeaderIdentifier = @"IconActionSectionHeader";

- (void)collectionView:(PSUICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulIconActionItem *item = self.items[indexPath.item];
    if (item.action) item.action();
    [self dismiss];
}

#pragma mark - AwfulSemiModalViewController

- (void)presentFromViewController:(UIViewController *)viewController
                         fromRect:(CGRect)rect
                           inView:(UIView *)view
{
    PSUICollectionViewFlowLayout *layout = (id)self.collectionView.collectionViewLayout;
    CGRect frame = self.view.frame;

    const float itemsPerRow = 3.0;
    const NSInteger numberOfRows = ceil([self.items count] / itemsPerRow);
    const CGFloat rowHeight = layout.itemSize.height + layout.minimumLineSpacing;
    const CGFloat margin = 20;
    frame.size.height = (numberOfRows * rowHeight) + margin;

    if ([self.title length] == 0) {
        layout.headerReferenceSize = CGSizeZero;
        self.collectionView.contentInset = UIEdgeInsetsZero;
    } else {
        UIFont *font = [AwfulIconActionSheetSectionHeader titleLabelFont];
        CGFloat availableWidth = CGRectGetWidth(frame) - SectionInsets.left - SectionInsets.right;
        CGSize textSize = [self.title sizeWithFont:font
                                 constrainedToSize:CGSizeMake(availableWidth, CGFLOAT_MAX)];
        layout.headerReferenceSize = textSize;
        frame.size.height += textSize.height;
        self.collectionView.contentInset = UIEdgeInsetsMake(12, 0, 0, 0);
    }
    self.view.frame = frame;
    [super presentFromViewController:viewController fromRect:rect inView:view];
}

- (void)userDismiss
{
    [self dismiss];
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _items = [NSMutableArray new];
    return self;
}

- (void)loadView
{
    PSUICollectionViewFlowLayout *layout = [PSUICollectionViewFlowLayout new];
    layout.itemSize = CGSizeMake(70, 90);
    layout.sectionInset = SectionInsets;
    layout.minimumInteritemSpacing = 27;
    layout.minimumLineSpacing = 12;
    PSUICollectionView *collectionView;
    collectionView = [[PSUICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 215)
                                          collectionViewLayout:layout];
    [collectionView registerClass:[AwfulIconActionCell class]
       forCellWithReuseIdentifier:CellIdentifier];
    [collectionView registerClass:[AwfulIconActionSheetSectionHeader class]
       forSupplementaryViewOfKind:PSTCollectionElementKindSectionHeader
              withReuseIdentifier:HeaderIdentifier];
    collectionView.collectionViewLayout = layout;
    collectionView.dataSource = self;
    collectionView.delegate = self;
    collectionView.bounces = NO;
    self.view = collectionView;
    self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleTopMargin);
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
}

const UIEdgeInsets SectionInsets = {15, 23, 5, 23};

@end


@interface AwfulIconActionSheetSectionHeader ()

@property (nonatomic) UILabel *titleLabel;

@end



@implementation AwfulIconActionSheetSectionHeader

- (NSString *)title
{
    return self.titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    self.titleLabel.text = title;
    CGSize size = [self.titleLabel sizeThatFits:self.titleLabel.bounds.size];
    CGRect bounds = self.bounds;
    bounds.size.height = size.height;
    self.bounds = bounds;
}

- (void)setTitleInsets:(UIEdgeInsets)titleInsets
{
    if (UIEdgeInsetsEqualToEdgeInsets(_titleInsets, titleInsets)) return;
    _titleInsets = titleInsets;
    [self setNeedsLayout];
}
                                      
+ (UIFont *)titleLabelFont
{
    return [UIFont systemFontOfSize:14];
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.titleLabel = [[UILabel alloc] initWithFrame:self.bounds];
    self.titleLabel.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                        UIViewAutoresizingFlexibleHeight);
    self.titleLabel.font = [[self class] titleLabelFont];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.shadowColor = [UIColor blackColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.titleLabel];
    return self;
}

- (void)layoutSubviews
{
    self.titleLabel.frame = UIEdgeInsetsInsetRect(self.bounds, self.titleInsets);
}

@end
