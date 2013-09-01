//  AwfulPageTopBar.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrollViewTopBar.h"

@interface AwfulPageTopBar : AwfulScrollViewTopBar

@property (readonly, weak, nonatomic) UIButton *goToForumButton;

@property (readonly, weak, nonatomic) UIButton *loadReadPostsButton;

@property (readonly, weak, nonatomic) UIButton *scrollToBottomButton;

@end
