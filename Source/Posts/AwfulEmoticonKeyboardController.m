//
//  AwfulEmoticonKeyboardController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmoticonKeyboardController.h"

@interface AwfulEmoticonKeyboardController ()

@end

@implementation AwfulEmoticonKeyboardController



- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.frame = CGRectMake(0, 0, 700, 300);
    self.view.backgroundColor = [UIColor magentaColor];
    
    self.emoticonCollection.backgroundColor = [UIColor redColor];
    
    [self.view addSubview:self.emoticonCollection];
}


- (UICollectionView*) emoticonCollection {
    if (_emoticonCollection) return _emoticonCollection;
    
    _emoticonCollection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 500, 200)
                                             collectionViewLayout:[UICollectionViewFlowLayout new]];
    _emoticonCollection.dataSource = self;
    _emoticonCollection.delegate = self;
    return _emoticonCollection;
}

#pragma mark Collection View Data Source
-(int) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 10;
}

-(int) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 5;
}

-(UICollectionViewCell*) collectionView:(UICollectionView *)collectionView
                 cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell* cell = [UICollectionViewCell new];
    cell.backgroundColor = [UIColor blueColor];
    
    return cell;
}

#pragma mark – UICollectionViewDelegateFlowLayout

// 1
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(100, 100);
}

// 3
- (UIEdgeInsets)collectionView:
(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(50, 20, 50, 20);
}

@end
