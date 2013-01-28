//
//  AwfulEmoticonKeyboardController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmoticonChooserViewController.h"
#import "AwfulEmoticonChooserCellView.h"
#import "AwfulModels.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient+Emoticons.h"

@interface AwfulEmoticonKeyboardController ()

@end

@implementation AwfulEmoticonKeyboardController



- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.frame = CGRectMake(0, 0, 768, 264);
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    [self.fetchedResultsController performFetch:nil];
    
    if (self.fetchedResultsController.fetchedObjects.count == 0) {
            //[self.networkOperation cancel];
            id op = [[AwfulHTTPClient client] emoticonListAndThen:^(NSError *error)
                     {
                         if (error) {
                         }
                         else {
                             
                         }
                     }];
        NSLog(@"op%@",op);
    }
    
    [self.view addSubview:self.emoticonCollection];
    [self.view addSubview:self.pageControl];
    
    [[AwfulHTTPClient client] downloadUncachedEmoticons];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) return _fetchedResultsController;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulEmoticon entityName]];
    request.sortDescriptors = @[
    [NSSortDescriptor sortDescriptorWithKey:@"width" ascending:YES],
    [NSSortDescriptor sortDescriptorWithKey:@"code" ascending:YES]
    ];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:@"group"
                                                          cacheName:nil];
    return _fetchedResultsController;
}


- (UICollectionView*) emoticonCollection {
    if (_emoticonCollection) return _emoticonCollection;
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    //[flowLayout setItemSize:CGSizeMake(100, 44)];
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
                                           210);
    
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
    int test = [self.fetchedResultsController.sections[section] numberOfObjects];
    return test;
    
    int width = self.emoticonCollection.frame.size.width ;
    int height = self.emoticonCollection.frame.size.height;
    int numAcross = width / 100;
    int numDown = height / 40;
    
    return numAcross*numDown;
    
}

-(int) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.fetchedResultsController.sections.count;
}

-(UICollectionViewCell*) collectionView:(UICollectionView *)collectionView
                 cellForItemAtIndexPath:(NSIndexPath *)indexPath
{

    AwfulEmoticon *emoticon = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulEmoticonChooserCellView* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell"
                                                                           forIndexPath:indexPath];
    
    cell.textLabel.text = emoticon.code;
    
    cell.imageView.image = [UIImage imageWithContentsOfFile:emoticon.cachedPath];
    
    
    return (UICollectionViewCell*)cell;
}

#pragma mark – UICollectionViewDelegateFlowLayout
-(CGSize) collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    AwfulEmoticon *emoticon = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (CGSizeEqualToSize(emoticon.size, CGSizeZero))
        return CGSizeMake(100, 40);
    
    CGSize minSize = [emoticon.code sizeWithFont:[UIFont systemFontOfSize:10]];
    
    return CGSizeMake(MAX(MAX(emoticon.size.width,minSize.width+5),44), 44);
    
}

-(UIEdgeInsets) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {

    return UIEdgeInsetsMake(1,1,1,1);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    AwfulEmoticon *emoticon = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [self.delegate didChooseEmoticon:emoticon];
}




@end
