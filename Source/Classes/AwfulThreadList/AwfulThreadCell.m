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
@synthesize tagContainerView = _tagContainerView;


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

-(void) layoutSubviews {
    [super layoutSubviews];
    if(self.ratingImage.hidden) {
        self.tagContainerView.center = CGPointMake(self.tagContainerView.center.x, self.contentView.center.y);
        
    } else {
        CGRect frame = self.tagContainerView.frame;
        frame.origin.y = 5;
        self.tagContainerView.frame = frame;
    } 
    
    float goal_width = self.frame.size.width-130;
    float title_xpos = 60;
    
    
    // size and positioning of labels   
    CGSize title_size = [self.thread.title sizeWithFont:self.threadTitleLabel.font constrainedToSize:CGSizeMake(goal_width, 60)];
    
    float y_pos = (THREAD_HEIGHT - title_size.height)/2 - 4;
    self.threadTitleLabel.frame = CGRectMake(title_xpos, y_pos, title_size.width, title_size.height);
    
    self.pagesLabel.frame = CGRectMake(title_xpos, CGRectGetMaxY(self.threadTitleLabel.frame)+2, self.pagesLabel.frame.size.width, 10);
    
    [self.unreadButton removeFromSuperview];
    
    [self.sticky removeFromSuperview];
    if(self.thread.stickyIndex.integerValue != NSNotFound) {  
        CGRect refRect = self.tagContainerView.frame;
        if(self.tagImage.hidden == NO) {
            float x = refRect.origin.x + refRect.size.width - self.sticky.frame.size.width + 1;
            float y = refRect.origin.y + refRect.size.height - self.sticky.frame.size.height + 1;
            self.sticky.frame = CGRectMake(x, y, self.sticky.frame.size.width, self.sticky.frame.size.height);
            [self.contentView addSubview:self.sticky];
        }
    }
}

-(void)configureForThread:(AwfulThread *)thread
{
    self.thread = thread;
    self.contentView.backgroundColor = [self getBackgroundColorForThread:thread];
    
    [self.tagLabel removeFromSuperview];
    
    [self configureTagImage];
        
    
    double rating = self.thread.threadRating.doubleValue;
    
    if (rating > 0) {
        int ratingImageNum;
        if (rating < 1.5)
            ratingImageNum = 1;
        
        else if (rating < 2.5)
            ratingImageNum = 2;
        
        else if (rating < 3.5)
            ratingImageNum = 3;
        
        else if (rating < 4.5)
            ratingImageNum = 4;
        
        else 
            ratingImageNum = 5;
        
        
        self.ratingImage.hidden = NO;
        self.ratingImage.image = [UIImage imageNamed:[NSString stringWithFormat:@"rating%i.png", ratingImageNum]];
    }
    else 
        self.ratingImage.hidden = YES;
    
    if([thread.threadRating integerValue] == NSNotFound || [thread.threadRating intValue] == -1) {
        self.ratingImage.hidden = YES;
    } else {
        if([thread.threadRating integerValue] <= 5) {
            
        } else {
            self.ratingImage.hidden = YES;
        }
    }


    
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
    
    if (thread.totalUnreadPosts.intValue >= 0) {
        self.badgeString = unread_str;
        self.badgeColor = [UIColor colorWithRed:0 green:.4 blue:.6 alpha:1];
    }

    self.threadTitleLabel.text = thread.title;
    

    


}

-(void) configureTagImage {
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
    
    [self.tagContainerView.layer setBorderColor:[[UIColor blackColor] CGColor]];
    [self.tagContainerView.layer setBorderWidth:1.0];
    
    [self.sticky removeFromSuperview];
    if([[self.thread stickyIndex] integerValue] != NSNotFound) {  
        CGRect refRect = self.tagContainerView.frame;
        if(self.tagImage.hidden == NO) {
            float x = refRect.origin.x + refRect.size.width - self.sticky.frame.size.width + 1;
            float y = refRect.origin.y + refRect.size.height - self.sticky.frame.size.height + 1;
            self.sticky.frame = CGRectMake(x, y, self.sticky.frame.size.width, self.sticky.frame.size.height);
            [self.contentView addSubview:self.sticky];
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willLoadThreadPage:)
                                                 name:AwfulPageWillLoadNotification 
                                               object:self.thread];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didLoadThreadPage:)
                                                 name:AwfulPageDidLoadNotification 
                                               object:self.thread];

    self.secondTagImage.hidden = YES;
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

-(void) willLoadThreadPage:(NSNotification*)notification {
    AwfulThread *thread = notification.object;
    if (thread.threadID.intValue != self.thread.threadID.intValue) return;
    UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] 
                                    initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleGray)
                                    ];
    self.accessoryView = act;
    [act startAnimating];
    self.badge.hidden = YES;
}

-(void) didLoadThreadPage:(NSNotification*)notification {
    AwfulThread *thread = notification.object;
    if (thread.threadID.intValue != self.thread.threadID.intValue) return;
    self.accessoryView = nil;
    self.badge.hidden = NO;
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