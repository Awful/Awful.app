//  AwfulPostsViewTopBar.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScrollViewTopBar.h"

@interface AwfulPostsViewTopBar : AwfulScrollViewTopBar

@property (readonly, strong, nonatomic) UIButton *parentForumButton;

@property (readonly, strong, nonatomic) UIButton *previousPostsButton;

@property (readonly, strong, nonatomic) UIButton *scrollToBottomButton;

@end
