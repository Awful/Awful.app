//  AwfulActionViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulActionViewController.h"
#import "AwfulActionView.h"
#import "AwfulIconActionCell.h"

@interface AwfulActionViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (readonly, strong, nonatomic) AwfulActionView *actionView;

@end

@implementation AwfulActionViewController
{
    NSMutableArray *_items;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) return nil;
    
    _items = [NSMutableArray new];
    
    return self;
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

- (AwfulActionView *)actionView
{
    return (AwfulActionView *)self.view;
}

- (void)loadView
{
    AwfulActionView *actionView = [AwfulActionView new];
    [actionView.collectionView registerClass:[AwfulIconActionCell class] forCellWithReuseIdentifier:CellIdentifier];
    actionView.collectionView.dataSource = self;
    actionView.collectionView.delegate = self;
    self.view = actionView;
}

- (void)themeDidChange
{
    [super themeDidChange];
    AwfulTheme *theme = self.theme;
    AwfulActionView *actionView = self.actionView;
    actionView.tintColor = theme[@"tintColor"];
    actionView.backgroundColor = theme[@"sheetBackgroundColor"];
    actionView.titleLabel.textColor = theme[@"sheetTitleColor"];
    actionView.titleBackgroundColor = theme[@"sheetTitleBackgroundColor"];
    [actionView.collectionView reloadItemsAtIndexPaths:[actionView.collectionView indexPathsForVisibleItems]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.actionView.titleLabel.text = self.title;
}

- (CGSize)preferredContentSize
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        CGRect bounds = self.view.bounds;
        bounds.size.width = 320;
        self.view.bounds = bounds;
    }
    [self.view sizeToFit];
    return self.view.bounds.size;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return _items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulIconActionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    AwfulIconActionItem *item = _items[indexPath.item];
    cell.titleLabel.text = item.title;
    cell.titleLabel.textColor = self.theme[@"sheetTextColor"];
    cell.iconImageView.image = item.icon;
    cell.tintColor = self.theme[item.themeKey];
    cell.isAccessibilityElement = YES;
    cell.accessibilityLabel = item.title;
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    return cell;
}

static NSString * const CellIdentifier = @"IconActionCell";

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulIconActionItem *item = _items[indexPath.item];
    [self dismissCompletion:item.action];
}

@end
