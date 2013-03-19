//
//  AwfulPageTopBar.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulScrollViewTopBar.h"

@interface AwfulPageTopBar : AwfulScrollViewTopBar

@property (readonly, weak, nonatomic) UIButton *goToForumButton;

@property (readonly, weak, nonatomic) UIButton *loadReadPostsButton;

@property (readonly, weak, nonatomic) UIButton *scrollToBottomButton;

@end
