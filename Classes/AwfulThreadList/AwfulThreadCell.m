//
//  AwfulThreadCell.m
//  Awful
//
//  Created by Sean Berry on 2/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadCell.h"
#import "AwfulForum.h"
#import "AwfulUtil.h"
#import "AwfulNavigator.h"
#import "AwfulThreadListActions.h"

@implementation AwfulThreadCell

@synthesize threadTitleLabel, pagesLabel, unreadButton, sticky, thread;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self=[super initWithCoder:aDecoder])) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(openThreadlistOptions)];
        [self addGestureRecognizer:press];
    }
    return self;
}

-(void)setUnreadButton:(UIButton *)anUnreadButton
{
    if(unreadButton != anUnreadButton) {
        unreadButton = anUnreadButton;
        UIImage *number_back = [UIImage imageNamed:@"number-background.png"];
        UIImage *stretch_back = [number_back stretchableImageWithLeftCapWidth:15.5 topCapHeight:9.5];
        [self.unreadButton setBackgroundImage:stretch_back forState:UIControlStateDisabled];
    }
}

-(void)configureForThread:(AwfulThread *)aThread
{
    self.thread = aThread;
    self.contentView.backgroundColor = [self getBackgroundColorForThread:self.thread];
    
    if(self.thread.isLocked) {
        self.contentView.alpha = 0.5;
    } else {
        self.contentView.alpha = 1.0;
    }
    
    // Content
    int total_pages = ((thread.totalReplies-1)/getPostsPerPage()) + 1;
    self.pagesLabel.text = [NSString stringWithFormat:@"Pages: %d", total_pages];
    
    NSString *unread_str = [NSString stringWithFormat:@"%d", self.thread.totalUnreadPosts];
    [self.unreadButton setTitle:unread_str forState:UIControlStateNormal];
    
    self.threadTitleLabel.text = thread.title;
    
    self.unreadButton.hidden = NO;
    self.unreadButton.alpha = 1.0;
    
    float goal_width = self.frame.size.width-100;
    
    if(self.thread.totalUnreadPosts == -1) {
        self.unreadButton.hidden = YES;
        goal_width += 60;
    } else if(thread.totalUnreadPosts == 0) {
        [self.unreadButton setTitle:@"0" forState:UIControlStateNormal];
        self.unreadButton.alpha = 0.5;
    }
    
    // size and positioning of labels   
    CGSize title_size = [thread.title sizeWithFont:self.threadTitleLabel.font constrainedToSize:CGSizeMake(goal_width, 60)];
    
    float thread_height = [AwfulUtil getThreadCellHeight];
    
    float y_pos = (thread_height - title_size.height)/2 - 4;
    self.threadTitleLabel.frame = CGRectMake(20, y_pos, title_size.width, title_size.height);
    
    CGSize unread_size = [unread_str sizeWithFont:self.unreadButton.titleLabel.font];
    float unread_x = self.frame.size.width-30-unread_size.width;
    self.unreadButton.frame = CGRectMake(unread_x, thread_height/2 - 10, unread_size.width+20, 20);
    
    self.pagesLabel.frame = CGRectMake(20, CGRectGetMaxY(self.threadTitleLabel.frame)+2, 100, 10);
    
    // Stickied?
    [self.sticky removeFromSuperview];
    if(thread.isStickied) {            
        self.sticky.frame = CGRectMake(CGRectGetMinX(self.threadTitleLabel.frame)-16, (thread_height-title_size.height)/2 - 3, 12, 12);
        [self.contentView addSubview:self.sticky];
    }
}

-(UIColor *)getBackgroundColorForThread : (AwfulThread *)aThread
{
    float offwhite = 241.0/255;
    UIColor *back_color = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    
    if(aThread.starCategory == AwfulStarCategoryBlue) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    } else if(aThread.starCategory == AwfulStarCategoryRed) {
        back_color = [UIColor colorWithRed:242.0/255 green:220.0/255 blue:220.0/255 alpha:1.0];
    } else if(aThread.starCategory == AwfulStarCategoryYellow) {
        back_color = [UIColor colorWithRed:242.0/255 green:242.0/255 blue:220.0/255 alpha:1.0];
    } else if(aThread.seen) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    }
    
    return back_color;
}

-(void)openThreadlistOptions
{
    AwfulNavigator *nav = getNavigator();
    if(nav.actions == nil) {
        AwfulThreadListActions *actions = [[AwfulThreadListActions alloc] initWithAwfulThread:self.thread];
        nav.actions = actions;
    }
}

@end