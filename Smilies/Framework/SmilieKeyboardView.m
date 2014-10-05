//  SmilieKeyboardView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieKeyboardView.h"
#import <FLAnimatedImage/FLAnimatedImage.h>
#import "SmilieCell.h"
#import "Smilie.h"

@interface SmilieKeyboardView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *hairlineConstraints;

@end

@implementation SmilieKeyboardView

+ (instancetype)newFromNib
{
    return [[NSBundle bundleForClass:[SmilieKeyboardView class]] loadNibNamed:@"SmilieKeyboardView" owner:nil options:nil][0];
}

- (void)setDataSource:(id<SmilieKeyboardDataSource>)dataSource
{
    _dataSource = dataSource;
    [self.collectionView reloadData];
}

- (void)setCollectionView:(UICollectionView *)collectionView
{
    _collectionView = collectionView;
    [collectionView registerClass:[SmilieCell class] forCellWithReuseIdentifier:CellIdentifier];
}

- (void)updateConstraints
{
    for (NSLayoutConstraint *constraint in self.hairlineConstraints) {
        constraint.constant = 0.5;
    }
    [super updateConstraints];
}

- (void)reloadData
{
    [self.collectionView reloadData];
}

- (IBAction)didTapDelete
{
    [self.delegate deleteBackwardForSmilieKeyboard:self];
}

- (IBAction)didTapNextKeyboard
{
    [self.delegate advanceToNextInputModeForSmilieKeyboard:self];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [self.dataSource numberOfSectionsInSmilieKeyboard:self];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self.dataSource smilieKeyboard:self numberOfSmiliesInSection:section];
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
    
    if (!cell.selectedBackgroundView) cell.selectedBackgroundView = [UIView new];
    cell.selectedBackgroundView.backgroundColor = self.selectedBackgroundColor;
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    cell.contentView.backgroundColor = cell.selectedBackgroundView.backgroundColor;
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    cell.contentView.backgroundColor = nil;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.dataSource smilieKeyboard:self sizeOfSmilieAtIndexPath:indexPath];
}

static NSString * const CellIdentifier = @"SmilieCell";

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.delegate smilieKeyboard:self didTapSmilieAtIndexPath:indexPath];
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];
}

@end
