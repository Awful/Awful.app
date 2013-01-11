//
//  AwfulEmoticonKeyboardController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmoticonKeyboardController.h"
#import "AwfulEmoticonChooserCellView.h"

@interface AwfulEmoticonKeyboardController ()

@end

@implementation AwfulEmoticonKeyboardController



- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.frame = CGRectMake(0, 0, 768, 264);
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    [self.view addSubview:self.emoticonCollection];
    [self.view addSubview:self.pageControl];
}


- (UICollectionView*) emoticonCollection {
    if (_emoticonCollection) return _emoticonCollection;
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    [flowLayout setItemSize:CGSizeMake(100, 40)];
    [flowLayout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
    
    _emoticonCollection = [[UICollectionView alloc] initWithFrame:self.view.frame
                                             collectionViewLayout:flowLayout
                           ];
    
    _emoticonCollection.backgroundColor = [UIColor clearColor];
    _emoticonCollection.dataSource = self;
    _emoticonCollection.delegate = self;
    _emoticonCollection.autoresizingMask = (UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth);
    _emoticonCollection.pagingEnabled = YES;
    _emoticonCollection.bounds = CGRectMake(0, 0, _emoticonCollection.frame.size.width, _emoticonCollection.frame.size.height);
    
    _emoticonCollection.frame = CGRectMake(0,
                                           10,
                                           self.view.frame.size.width,
                                           200);
    
    [_emoticonCollection registerClass:[AwfulEmoticonChooserCellView class] forCellWithReuseIdentifier:@"cell"];
    
    
    return _emoticonCollection;
}

-(UIPageControl*) pageControl {
    if (_pageControl) return _pageControl;
    
    _pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0,
                                                                   0,
                                                                   self.view.frame.size.width,
                                                                   10)
                    ];
    _pageControl.pageIndicatorTintColor = [UIColor darkGrayColor];
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _pageControl.numberOfPages = self.emoticonCollection.numberOfSections;
    
    return _pageControl;
}

#pragma mark Collection View Data Source
-(int) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    int width = self.emoticonCollection.frame.size.width ;
    int height = self.emoticonCollection.frame.size.height;
    int numAcross = width / 100;
    int numDown = height / 40;
    
    return numAcross*numDown;
}

-(int) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 10;
}

-(UICollectionViewCell*) collectionView:(UICollectionView *)collectionView
                 cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulEmoticonChooserCellView* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell"
                                                                           forIndexPath:indexPath];
    
    cell.textLabel.text = [NSString stringWithFormat:@"(%i,%i)", indexPath.section, indexPath.row];
    cell.backgroundColor = [UIColor grayColor];
    cell.imageView.image = [UIImage imageNamed:@"star-off-dark.png"];
    
    return (UICollectionViewCell*)cell;
}

#pragma mark – UICollectionViewDelegateFlowLayout


-(UIEdgeInsets) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {

    return UIEdgeInsetsMake(1,1,1,1);
}




@end
