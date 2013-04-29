//
//  AwfulIconActionSheet.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-25.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulIconActionSheet.h"
#import "AwfulIconActionCell.h"
#import "AwfulIconActionItem.h"
#import "PSTCollectionView.h"

@interface AwfulIconActionSheet () <PSUICollectionViewDataSource, PSUICollectionViewDelegate>

@property (nonatomic) NSMutableArray *items;
@property (readonly, nonatomic) PSUICollectionView *collectionView;

@end


@interface AwfulIconActionSheetSectionHeader : PSUICollectionReusableView

@property (copy, nonatomic) NSString *title;

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

- (void)presentFromViewController:(UIViewController *)viewController fromView:(UIView *)view
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.coverView.backgroundColor = nil;
    }
    PSUICollectionViewFlowLayout *layout = (id)self.collectionView.collectionViewLayout;
    CGRect frame = self.view.frame;
    frame.size.height = 225;
    if ([self.title length] == 0) {
        layout.headerReferenceSize = CGSizeZero;
        self.collectionView.contentInset = UIEdgeInsetsZero;
    } else {
        UIFont *font = [AwfulIconActionSheetSectionHeader titleLabelFont];
        CGSize textSize = [self.title sizeWithFont:font constrainedToSize:
                           CGSizeMake(CGRectGetWidth(frame), CGFLOAT_MAX)];
        layout.headerReferenceSize = textSize;
        frame.size.height += textSize.height;
        self.collectionView.contentInset = UIEdgeInsetsMake(12, 0, 0, 0);
    }
    self.view.frame = frame;
    [super presentFromViewController:viewController fromView:view];
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
    layout.itemSize = CGSizeMake(60, 90);
    layout.sectionInset = UIEdgeInsetsMake(15, 30, 5, 30);
    layout.minimumInteritemSpacing = 40;
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
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
}

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
                                      
+ (UIFont *)titleLabelFont
{
    return [UIFont systemFontOfSize:13];
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

@end
