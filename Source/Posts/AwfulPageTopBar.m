//  AwfulPageTopBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPageTopBar.h"

@interface AwfulPageTopBar ()

@property (weak, nonatomic) UIButton *goToForumButton;
@property (weak, nonatomic) UIButton *loadReadPostsButton;
@property (weak, nonatomic) UIButton *scrollToBottomButton;

@end


@implementation AwfulPageTopBar

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UIButton *goToForumButton = [self makeButton];
    [goToForumButton setTitle:@"Parent Forum" forState:UIControlStateNormal];
    goToForumButton.accessibilityLabel = @"Parent forum";
    goToForumButton.accessibilityHint = @"Opens this thread's forum";
    _goToForumButton = goToForumButton;
    
    UIButton *loadReadPostsButton = [self makeButton];
    [loadReadPostsButton setTitle:@"Previous Posts" forState:UIControlStateNormal];
    loadReadPostsButton.accessibilityLabel = @"Previous posts";
    _loadReadPostsButton = loadReadPostsButton;
    
    UIButton *scrollToBottomButton = [self makeButton];
    [scrollToBottomButton setTitle:@"Scroll To End" forState:UIControlStateNormal];
    scrollToBottomButton.accessibilityLabel = @"Scroll to end";
    _scrollToBottomButton = scrollToBottomButton;
    
    return self;
}

- (UIButton *)makeButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.font = [UIFont systemFontOfSize:12];
    [self addSubview:button];
    return button;
}

- (void)layoutSubviews
{
    CGSize buttonSize = CGSizeMake(floorf((CGRectGetWidth(self.bounds) - 2) / 3),
                                   CGRectGetHeight(self.bounds) - 1);
    CGFloat extraMiddleWidth = CGRectGetWidth(self.bounds) - buttonSize.width * 3 - 2;
    self.goToForumButton.frame = (CGRect){ .size = buttonSize };
    self.loadReadPostsButton.frame = CGRectMake(CGRectGetMaxX(self.goToForumButton.frame) + 1, 0,
                                                buttonSize.width + extraMiddleWidth, buttonSize.height);
    self.scrollToBottomButton.frame = (CGRect){
        .origin.x = CGRectGetMaxX(self.loadReadPostsButton.frame) + 1,
        .size = buttonSize
    };
}

@end
