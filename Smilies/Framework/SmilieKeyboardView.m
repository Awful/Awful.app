//  SmilieKeyboardView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieKeyboardView.h"
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

- (void)setCollectionView:(UICollectionView *)collectionView
{
    _collectionView = collectionView;
    [collectionView registerClass:[SmilieCell class] forCellWithReuseIdentifier:CellIdentifier];
}

- (void)setFlowLayout:(UICollectionViewFlowLayout *)flowLayout
{
    _flowLayout = flowLayout;
    flowLayout.estimatedItemSize = CGSizeMake(38, 25);
}

- (void)updateConstraints
{
    for (NSLayoutConstraint *constraint in self.hairlineConstraints) {
        constraint.constant = 0.5;
    }
    [super updateConstraints];
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
    return 8;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 100;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SmilieCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    NSBundle *frameworkBundle = [NSBundle bundleForClass:[SmilieKeyboardView class]];
    cell.imageView.image = [UIImage imageNamed:@"emot-backtowork" inBundle:frameworkBundle compatibleWithTraitCollection:nil];
    
    if (!cell.selectedBackgroundView) cell.selectedBackgroundView = [UIView new];
    cell.selectedBackgroundView.backgroundColor = self.selectedBackgroundColor;
    return cell;
}

static NSString * const CellIdentifier = @"SmilieCell";

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
//    SmilieCell *cell = (SmilieCell *)[collectionView cellForItemAtIndexPath:indexPath];
    Smilie *smilie = [Smilie new];
//    smilie.image = cell.imageView.image;
    smilie.text = @":backtowork:";
    [self.delegate smilieKeyboard:self didTapSmilie:smilie];
    
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];
}

@end
