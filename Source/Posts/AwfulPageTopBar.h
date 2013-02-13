//
//  AwfulPageTopBar.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-12.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulScrollViewTopBar.h"

@interface AwfulPageTopBar : AwfulScrollViewTopBar

@property (readonly, weak, nonatomic) UIButton *goToForumButton;

@property (readonly, weak, nonatomic) UIButton *loadReadPostsButton;

@property (readonly, weak, nonatomic) UIButton *scrollToBottomButton;

@end
