//
//  AwfulThreadCell.m
//  Awful
//
//  Created by Sean Berry on 2/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "AwfulThreadCell.h"
#import "AwfulForum.h"
#import "AwfulUtil.h"
#import "AwfulThreadListActions.h"
#import "AwfulThread.h"

#define THREAD_HEIGHT 72

@implementation AwfulThreadCell

@synthesize thread = _thread;
@synthesize threadTitleLabel = _threadTitleLabel;
@synthesize pagesLabel = _pagesLabel;
@synthesize unreadButton = _unreadButton;
@synthesize sticky = _sticky;
@synthesize tagImage = _tagImage;
@synthesize ratingImage = _ratingImage;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self=[super initWithCoder:aDecoder])) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(openThreadlistOptions)];
        [self addGestureRecognizer:press];
    }
    return self;
}

-(void)setUnreadButton:(UIButton *)unreadButton
{
    if(unreadButton != _unreadButton) {
        _unreadButton = unreadButton;
        UIImage *number_back = [UIImage imageNamed:@"number-background.png"];
        UIImage *stretch_back = [number_back stretchableImageWithLeftCapWidth:15.5 topCapHeight:9.5];
        [_unreadButton setBackgroundImage:stretch_back forState:UIControlStateDisabled];
    }
}

-(void)configureForThread:(AwfulThread *)thread
{
    self.thread = thread;
    self.contentView.backgroundColor = [self getBackgroundColorForThread:thread];
    
    NSString *minus_extension = [[self.thread.threadIconImageURL lastPathComponent] stringByDeletingPathExtension];
    NSURL *tag_url = [[NSBundle mainBundle] URLForResource:minus_extension withExtension:@"png"];
    if(tag_url != nil) {
        [self addSubview:self.tagImage];
        [self.tagImage setImage:[UIImage imageNamed:[tag_url lastPathComponent]]];
        [self.tagImage.layer setBorderColor:[[UIColor blackColor] CGColor]];
        [self.tagImage.layer setBorderWidth:1.0];
    } else {
        [self.tagImage removeFromSuperview];
    }
    
    if(thread.isLocked) {
        self.contentView.alpha = 0.5;
    } else {
        self.contentView.alpha = 1.0;
    }
    
    // Content
    int total_pages = ((thread.totalReplies-1)/getPostsPerPage()) + 1;
    self.pagesLabel.text = [NSString stringWithFormat:@"Pages: %d", total_pages];
    
    NSString *unread_str = [NSString stringWithFormat:@"%d", thread.totalUnreadPosts];
    [self.unreadButton setTitle:unread_str forState:UIControlStateNormal];
    
    self.threadTitleLabel.text = thread.title;
    
    self.unreadButton.hidden = NO;
    self.unreadButton.alpha = 1.0;
    
    float goal_width = self.frame.size.width-130;
    float title_xpos = 60;
    
    if(thread.totalUnreadPosts == -1) {
        self.unreadButton.hidden = YES;
        goal_width += 60;
    } else if(thread.totalUnreadPosts == 0) {
        [self.unreadButton setTitle:@"0" forState:UIControlStateNormal];
        self.unreadButton.alpha = 0.5;
    }
    
    // size and positioning of labels   
    CGSize title_size = [thread.title sizeWithFont:self.threadTitleLabel.font constrainedToSize:CGSizeMake(goal_width, 60)];
    
    float y_pos = (THREAD_HEIGHT - title_size.height)/2 - 4;
    self.threadTitleLabel.frame = CGRectMake(title_xpos, y_pos, title_size.width, title_size.height);
    
    CGSize unread_size = [unread_str sizeWithFont:self.unreadButton.titleLabel.font];
    float unread_x = self.frame.size.width-30-unread_size.width;
    self.unreadButton.frame = CGRectMake(unread_x, THREAD_HEIGHT/2 - 10, unread_size.width+20, 20);
    
    self.pagesLabel.frame = CGRectMake(title_xpos, CGRectGetMaxY(self.threadTitleLabel.frame)+2, 100, 10);
    
    // Stickied?
    [self.sticky removeFromSuperview];
    if(thread.isStickied) {            
        self.sticky.frame = CGRectMake(CGRectGetMinX(self.threadTitleLabel.frame)-16, (THREAD_HEIGHT-title_size.height)/2 - 3, 12, 12);
        [self.contentView addSubview:self.sticky];
    }
}

-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread
{
    float offwhite = 241.0/255;
    UIColor *back_color = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    
    if(thread.starCategory == AwfulStarCategoryBlue) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    } else if(thread.starCategory == AwfulStarCategoryRed) {
        back_color = [UIColor colorWithRed:242.0/255 green:220.0/255 blue:220.0/255 alpha:1.0];
    } else if(thread.starCategory == AwfulStarCategoryYellow) {
        back_color = [UIColor colorWithRed:242.0/255 green:242.0/255 blue:220.0/255 alpha:1.0];
    } else if(thread.seen) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    }
    
    return back_color;
}

-(void)openThreadlistOptions
{
    /*AwfulNavigator *nav = getNavigator();
    if(nav.actions == nil) {
        AwfulThreadListActions *actions = [[AwfulThreadListActions alloc] initWithAwfulThread:self.thread];
        [nav setActions:actions];
    }*/
}

@end