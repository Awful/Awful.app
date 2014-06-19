//  AwfulPostsViewTopBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsViewTopBar.h"

@implementation AwfulPostsViewTopBar

- (id)initWithFrame:(CGRect)frame
{
    frame.size.height = 40;
    if ((self = [super initWithFrame:frame])) {
        _parentForumButton = [UIButton new];
        [_parentForumButton setTitle:@"Parent Forum" forState:UIControlStateNormal];
        _parentForumButton.accessibilityLabel = @"Parent forum";
        _parentForumButton.accessibilityHint = @"Opens this thread's forum";
        _parentForumButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [self addSubview:_parentForumButton];
        
        _previousPostsButton = [UIButton new];
        [_previousPostsButton setTitle:@"Previous Posts" forState:UIControlStateNormal];
        _previousPostsButton.accessibilityLabel = @"Previous posts";
        _previousPostsButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [self addSubview:_previousPostsButton];
        
        _scrollToBottomButton = [UIButton new];
        [_scrollToBottomButton setTitle:@"Scroll To End" forState:UIControlStateNormal];
        _scrollToBottomButton.accessibilityLabel = @"Scroll to end";
        _scrollToBottomButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [self addSubview:_scrollToBottomButton];
    }
    return self;
}

- (void)layoutSubviews
{
    CGFloat buttonWidth = floor((CGRectGetWidth(self.bounds) - 2) / 3);
    CGFloat leftoverWidth = CGRectGetWidth(self.bounds) - buttonWidth * 3 - 2;
    CGFloat buttonHeight = CGRectGetHeight(self.bounds);

    self.parentForumButton.frame = CGRectMake(0, 0, buttonWidth, buttonHeight);
    self.previousPostsButton.frame = CGRectMake(CGRectGetMaxX(self.parentForumButton.frame) + 1, 0, buttonWidth + leftoverWidth, buttonHeight);
    self.scrollToBottomButton.frame = CGRectMake(CGRectGetMaxX(self.previousPostsButton.frame) + 1, 0, buttonWidth, buttonHeight);
}

@end
