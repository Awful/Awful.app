//  SmilieKeyboardView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieKeyboardView.h"
#import <FLAnimatedImage/FLAnimatedImage.h>
#import "Smilie.h"
#import "SmilieCell.h"

@interface SmilieKeyboardView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *sectionButtons;

@property (assign, nonatomic) NSInteger selectedSection;

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

- (void)setSelectedSection:(NSInteger)selectedSection
{
    _selectedSection = selectedSection;
    [self.sectionButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger i, BOOL *stop) {
        button.selected = i == (NSUInteger)selectedSection;
    }];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.selectedSection = 0;
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
    
    cell.normalBackgroundColor = self.normalBackgroundColor;
    cell.selectedBackgroundColor = self.selectedBackgroundColor;
    return cell;
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

static NSString * const CellIdentifier = @"SmilieCell";

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.delegate smilieKeyboard:self didTapSmilieAtIndexPath:indexPath];
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];
}

@end
