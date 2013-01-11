//
//  AwfulEmoticonKeyboardController.h
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulEmoticonKeyboardController : UIViewController <UICollectionViewDataSource,
                                                                UICollectionViewDelegateFlowLayout,
                                                                UIScrollViewDelegate>
@property (nonatomic,strong) UICollectionView* emoticonCollection;
@property (nonatomic,strong) UIPageControl* pageControl;
@end
