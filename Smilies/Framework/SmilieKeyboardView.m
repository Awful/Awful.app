//  SmilieKeyboardView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieKeyboardView.h"
#import <FLAnimatedImage/FLAnimatedImage.h>
#import "Smilie.h"
#import "SmilieAppContainer.h"
#import "SmilieCell.h"
#import "SmilieCollectionViewFlowLayout.h"

@interface SmilieKeyboardView () <SmilieCollectionViewFlowLayoutDataSource, UICollectionViewDelegateFlowLayout>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet SmilieCollectionViewFlowLayout *flowLayout;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *smilieListButtons;
@property (weak, nonatomic) IBOutlet UIView *noFavoritesNotice;
@property (weak, nonatomic) IBOutlet UILongPressGestureRecognizer *toggleFavoriteLongPressGestureRecognizer;

@property (assign, nonatomic) BOOL didScrollToStoredOffset;

@end

@implementation SmilieKeyboardView

+ (instancetype)newFromNib
{
    return [[NSBundle bundleForClass:[SmilieKeyboardView class]] loadNibNamed:@"SmilieKeyboardView" owner:nil options:nil][0];
}

- (void)setDataSource:(id<SmilieKeyboardDataSource>)dataSource
{
    _dataSource = dataSource;
    dataSource.smilieList = self.selectedSmilieList;
}

- (void)setCollectionView:(UICollectionView *)collectionView
{
    _collectionView = collectionView;
    [collectionView registerClass:[SmilieCell class] forCellWithReuseIdentifier:CellIdentifier];
}

- (void)setSelectedSmilieList:(SmilieList)selectedSmilieList
{
    BOOL didChange = _selectedSmilieList != selectedSmilieList;
    
    _selectedSmilieList = selectedSmilieList;
    
    if (selectedSmilieList != SmilieListFavorites) {
        self.noFavoritesNotice.hidden = YES;
    }
    [self.smilieListButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger i, BOOL *stop) {
        button.selected = i == (NSUInteger)selectedSmilieList;
    }];
    self.dataSource.smilieList = selectedSmilieList;
    SmilieKeyboardSetSelectedSmilieList(selectedSmilieList);
    
    if (didChange) {
        self.didScrollToStoredOffset = NO;
    }
    
    self.flowLayout.dragReorderingEnabled = selectedSmilieList == SmilieListFavorites;
    self.toggleFavoriteLongPressGestureRecognizer.enabled = selectedSmilieList != SmilieListFavorites;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.selectedSmilieList = SmilieKeyboardSelectedSmilieList();
}

- (void)reloadData
{
    [self.collectionView reloadData];
}

- (IBAction)didTapDelete
{
    [self.delegate deleteBackwardForSmilieKeyboard:self];
}

- (IBAction)didTapSmilieListButton:(UIButton *)button
{
    SmilieList smilieList = (SmilieList)[self.smilieListButtons indexOfObject:button];
    if (self.selectedSmilieList == smilieList) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]
                                    atScrollPosition:UICollectionViewScrollPositionTop
                                            animated:YES];
    } else {
        self.selectedSmilieList = smilieList;
    }
}

- (IBAction)didTapNextKeyboard
{
    [self.delegate advanceToNextInputModeForSmilieKeyboard:self];
}

- (IBAction)didLongPressCollectionView:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [sender locationInView:self.collectionView];
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
        if (indexPath) {
            [self.delegate smilieKeyboard:self didLongPressSmilieAtIndexPath:indexPath];
        }
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [self.dataSource numberOfSectionsInSmilieKeyboard:self];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSInteger numberOfSmilies = [self.dataSource smilieKeyboard:self numberOfSmiliesInSection:section];
    if (self.selectedSmilieList == SmilieListFavorites) {
        self.noFavoritesNotice.hidden = numberOfSmilies != 0;
    }
    return numberOfSmilies;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SmilieCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    id image = [self.dataSource smilieKeyboard:self imageOfSmilieAtIndexPath:indexPath];
    if ([image isKindOfClass:[FLAnimatedImage class]]) {
        cell.imageView.animatedImage = image;
    } else {
        cell.imageView.image =image;
    }
    
    cell.normalBackgroundColor = self.normalBackgroundColor;
    cell.selectedBackgroundColor = self.selectedBackgroundColor;
    return cell;
}

static NSString * const CellIdentifier = @"SmilieCell";

#pragma mark - SmilieCollectionViewFlowLayoutDataSource

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)oldIndexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    [self.dataSource smilieKeyboard:self dragSmilieFromIndexPath:oldIndexPath toIndexPath:newIndexPath];
}

- (void)collectionView:(UICollectionView *)collectionView didFinishDraggingItemToIndexPath:(NSIndexPath *)indexPath
{
    [self.dataSource smilieKeyboard:self didFinishDraggingSmilieToIndexPath:indexPath];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize imageSize = [self.dataSource smilieKeyboard:self sizeOfSmilieAtIndexPath:indexPath];
    const CGFloat margin = 4;
    const CGFloat minimumWidth = 50;
    return CGSizeMake(MAX(imageSize.width + margin, minimumWidth),
                      MAX(imageSize.height + margin, minimumWidth));
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Really I just want a "collection view did lay itself out" notification, but I guess this'll do.
    if (!self.didScrollToStoredOffset) {
        float scrollFraction = SmilieKeyboardScrollFractionForSmilieList(self.selectedSmilieList);
        if (fabsf(scrollFraction) > FLT_EPSILON) {
            collectionView.contentOffset = CGPointMake(0, scrollFraction * collectionView.contentSize.height);
            self.didScrollToStoredOffset = YES;
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.delegate smilieKeyboard:self didTapSmilieAtIndexPath:indexPath];
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        SmilieKeyboardSetScrollFractionForSmilieList(self.selectedSmilieList, scrollView.contentOffset.y / scrollView.contentSize.height);
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    SmilieKeyboardSetScrollFractionForSmilieList(self.selectedSmilieList, scrollView.contentOffset.y / scrollView.contentSize.height);
}

@end
