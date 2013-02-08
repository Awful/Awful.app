//
//  AwfulEmoticonKeyboardController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmoticonKeyboardController.h"
#import "AwfulEmoticonChooserCellView.h"
#import "AwfulModels.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient+Emoticons.h"

@interface AwfulEmoticonKeyboardController ()
@property (nonatomic) NSMutableArray *changeset;
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
                             //[self.fetchedResultsController performFetch:nil];
                         }
                     }];
        NSLog(@"op%@",op);
    }
    
    [self.view addSubview:self.emoticonCollection];
    [self.view addSubview:self.pageControl];
    

}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) return _fetchedResultsController;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulEmoticon entityName]];
    request.sortDescriptors = @[
    [NSSortDescriptor sortDescriptorWithKey:@"group.desc" ascending:YES],
    [NSSortDescriptor sortDescriptorWithKey:@"code" ascending:YES]
    ];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:@"group.desc"
                                                          cacheName:nil];
    _fetchedResultsController.delegate = self;
    return _fetchedResultsController;
}


- (PSTCollectionView*) emoticonCollection {
    if (_emoticonCollection) return _emoticonCollection;
    
    PSTCollectionViewFlowLayout *flowLayout = [[PSTCollectionViewFlowLayout alloc] init];
    //[flowLayout setItemSize:CGSizeMake(100, 44)];
    [flowLayout setScrollDirection:PSTCollectionViewScrollDirectionHorizontal];
    
    _emoticonCollection = [[PSTCollectionView alloc] initWithFrame:self.view.frame
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
    //_pageControl.pageIndicatorTintColor = [UIColor darkGrayColor];
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _pageControl.numberOfPages = self.emoticonCollection.numberOfSections;
    
    return _pageControl;
}

#pragma mark collection view delegate
- (void)collectionView:(PSTCollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    AwfulEmoticon *emoticon = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [self.delegate didChooseEmoticon:emoticon];
}

#pragma mark Collection View Data Source
-(int) collectionView:(PSTCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    int test = [self.fetchedResultsController.sections[section] numberOfObjects];
    return test;
}

-(int) numberOfSectionsInCollectionView:(PSTCollectionView *)collectionView {
    return self.fetchedResultsController.sections.count;
}

-(PSTCollectionViewCell*) collectionView:(PSTCollectionView *)collectionView
                 cellForItemAtIndexPath:(NSIndexPath *)indexPath
{

    AwfulEmoticon *emoticon = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulEmoticonChooserCellView* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell"
                                                                           forIndexPath:indexPath];
    
    cell.emoticon = emoticon;
    
    
    return (PSTCollectionViewCell*)cell;
}

#pragma mark – PSTCollectionViewDelegateFlowLayout
-(CGSize) collectionView:(PSTCollectionView *)collectionView
                  layout:(PSTCollectionView *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    AwfulEmoticon *emoticon = [self.fetchedResultsController objectAtIndexPath:indexPath];

    CGSize minSize = [emoticon.code sizeWithFont:[UIFont systemFontOfSize:10]];
    CGSize size = CGSizeMake(MAX(emoticon.size.width,minSize.width+5), 44);
    
    return size;
    
}

-(UIEdgeInsets) collectionView:(PSTCollectionView *)collectionView layout:(PSTCollectionView *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {

    return UIEdgeInsetsMake(1,1,1,1);
}


#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    self.changeset = [NSMutableArray new];
}


- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    [self.changeset addObject:^(PSTCollectionView* collectionView) {
        switch (type) {
            case NSFetchedResultsChangeInsert: {
                [collectionView insertItemsAtIndexPaths:@[newIndexPath]];
                break;
            }
            case NSFetchedResultsChangeDelete: {
                [collectionView deleteItemsAtIndexPaths:@[indexPath]];
                break;
            }
            case NSFetchedResultsChangeMove: {
                [collectionView moveItemAtIndexPath:indexPath
                                                  toIndexPath:newIndexPath];
                break;
            }
            case NSFetchedResultsChangeUpdate: {
                [collectionView reloadItemsAtIndexPaths:@[indexPath]];
                break;
            }
        }
     }];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    [self.changeset addObject:^(PSTCollectionView* collectionView) {
        switch (type) {
            case NSFetchedResultsChangeInsert: {
                [collectionView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
                break;
            }
            case NSFetchedResultsChangeDelete: {
                [collectionView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
                break;
            }
        }
    }];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.emoticonCollection performBatchUpdates:^{
        for(void(^block)(PSTCollectionView*) in self.changeset) {
            block(self.emoticonCollection);
        }
        
    }
                                      completion:^(BOOL finished) {
                                          
                                      }];
}




@end
