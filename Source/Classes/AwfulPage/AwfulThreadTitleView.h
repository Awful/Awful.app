//
//  AwfulThreadTitleView.h
//  Awful
//
//  Created by me on 6/25/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulPage;

@interface AwfulThreadTitleView : UIView

+(id) threadTitleViewWithPage:(AwfulPage*)page;

@property (nonatomic,strong) AwfulPage* page;
@property (nonatomic,strong) UIImageView* threadTag;
@property (nonatomic,strong) UILabel* title;

@end
