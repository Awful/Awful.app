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
#import "AwfulThread.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulUser+AwfulMethods.h"
#import "AwfulUser.h"
#import "AwfulThreadListController.h"

#define THREAD_HEIGHT 72

@implementation AwfulThreadCell

@synthesize thread = _thread;
@synthesize threadTitleLabel = _threadTitleLabel;
@synthesize pagesLabel = _pagesLabel;
@synthesize unreadButton = _unreadButton;
@synthesize sticky = _sticky;
@synthesize tagImage = _tagImage;
@synthesize secondTagImage = _secondTagImage;
@synthesize ratingImage = _ratingImage;
@synthesize threadListController = _threadListController;
@synthesize tagLabel = _tagLabel;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self=[super initWithCoder:aDecoder])) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(openThreadlistOptions:)];
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
    
    [self.tagLabel removeFromSuperview];
    
    NSURL *tag_url = [self.thread firstIconURL];
    if(tag_url != nil) {
        [self.tagImage setImage:[UIImage imageNamed:[tag_url lastPathComponent]]];
    } else {
        [self.tagImage setImage:nil];
        
        NSString *str = [[self.thread.threadIconImageURL lastPathComponent] stringByDeletingPathExtension];
        self.tagLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 45, 45)];
        self.tagLabel.text = str;
        self.tagLabel.textAlignment = UITextAlignmentCenter;
        self.tagLabel.numberOfLines = 2;
        self.tagLabel.lineBreakMode = UILineBreakModeCharacterWrap;
        self.tagLabel.textColor = [UIColor blackColor];
        self.tagLabel.font = [UIFont systemFontOfSize:8.0];
        [self.tagImage addSubview:self.tagLabel];
    }
    
    [self.tagImage.layer setBorderColor:[[UIColor blackColor] CGColor]];
    [self.tagImage.layer setBorderWidth:1.0];
    
    self.secondTagImage.hidden = YES;
    if(self.tagImage.hidden == NO) {
        NSURL *second_url = [self.thread secondIconURL];
        if(second_url != nil) {
            self.secondTagImage.hidden = NO;
            [self.secondTagImage setImage:[UIImage imageNamed:[second_url lastPathComponent]]];
        }
    }
    
    if([thread.threadRating integerValue] == NSNotFound || [thread.threadRating intValue] == -1) {
        self.ratingImage.hidden = YES;
    } else {
        self.ratingImage.hidden = NO;
        if([thread.threadRating integerValue] <= 5) {
            [self.ratingImage setImage:[UIImage imageNamed:[NSString stringWithFormat:@"rating%@.png", thread.threadRating]]];
        } else {
            self.ratingImage.hidden = YES;
        }
    }
    
    if(self.ratingImage.hidden) {
        self.tagImage.center = CGPointMake(self.tagImage.center.x, self.contentView.center.y);
        
    } else {
        CGRect frame = self.tagImage.frame;
        frame.origin.y = 5;
        self.tagImage.frame = frame;
    }
    self.secondTagImage.frame = CGRectMake(self.tagImage.frame.origin.x-1, self.tagImage.frame.origin.y-1, self.secondTagImage.frame.size.width, self.secondTagImage.frame.size.height);
    
    if([thread.isLocked boolValue]) {
        self.contentView.alpha = 0.5;
    } else {
        self.contentView.alpha = 1.0;
    }
    
    // Content
    int posts_per_page = [AwfulUser currentUser].postsPerPageValue;
    int total_pages = (([thread.totalReplies intValue]-1)/posts_per_page) + 1;
    self.pagesLabel.text = [NSString stringWithFormat:@"Pages: %d, Killed by %@", total_pages, thread.lastPostAuthorName];
    
    NSString *unread_str = [NSString stringWithFormat:@"%@", thread.totalUnreadPosts];
    [self.unreadButton setTitle:unread_str forState:UIControlStateNormal];
    
    self.threadTitleLabel.text = thread.title;
    
    self.unreadButton.hidden = NO;
    self.unreadButton.alpha = 1.0;
    
    float goal_width = self.frame.size.width-130;
    float title_xpos = 60;
    
    if([thread.totalUnreadPosts intValue] == -1) {
        self.unreadButton.hidden = YES;
        goal_width += 60;
    } else if([thread.totalUnreadPosts intValue] == 0) {
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
    
    self.pagesLabel.frame = CGRectMake(title_xpos, CGRectGetMaxY(self.threadTitleLabel.frame)+2, self.pagesLabel.frame.size.width, 10);
    
    [self.sticky removeFromSuperview];
    if([[thread stickyIndex] integerValue] != NSNotFound) {  
        if(self.tagImage.hidden == NO) {
            float x = self.tagImage.frame.origin.x + self.tagImage.frame.size.width - self.sticky.frame.size.width + 1;
            float y = self.tagImage.frame.origin.y + self.tagImage.frame.size.height - self.sticky.frame.size.height + 1;
            self.sticky.frame = CGRectMake(x, y, self.sticky.frame.size.width, self.sticky.frame.size.height);
            [self.contentView addSubview:self.sticky];
        }
    }
}

-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread
{
    float offwhite = 241.0/255;
    UIColor *back_color = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    
    AwfulStarCategory star = [thread.starCategory intValue];
    if(star == AwfulStarCategoryBlue) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    } else if(star == AwfulStarCategoryRed) {
        back_color = [UIColor colorWithRed:242.0/255 green:220.0/255 blue:220.0/255 alpha:1.0];
    } else if(star == AwfulStarCategoryYellow) {
        back_color = [UIColor colorWithRed:242.0/255 green:242.0/255 blue:220.0/255 alpha:1.0];
    } else if([thread.seen boolValue]) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    }
    
    return back_color;
}

-(void)openThreadlistOptions : (UIGestureRecognizer *)gesture
{
    if([gesture state] == UIGestureRecognizerStateBegan) {
        [self.threadListController showThreadActionsForThread:self.thread];
    }
}

@end

@implementation AwfulLoadingThreadCell

@synthesize activity = _activity;

-(void)setActivityViewVisible : (BOOL)visible
{
    self.activity.hidden = !visible;
    if(visible) {
        [self.activity startAnimating];
    } else {
        [self.activity stopAnimating];
    }
}

@end