//
//  AwfulEmoticonKeyboardController.h
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PSTCollectionView.h"

@interface AwfulEmoticonKeyboardController : UIViewController <PSTCollectionViewDataSource,
                                                                PSTCollectionViewDelegateFlowLayout,
                                                                UIScrollViewDelegate,
                                                                NSFetchedResultsControllerDelegate>
@property (nonatomic,strong) PSTCollectionView* emoticonCollection;
@property (nonatomic,strong) UIPageControl* pageControl;
@property (nonatomic,strong) NSFetchedResultsController* fetchedResultsController;
@end
