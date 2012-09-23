//
//  AwfulThreadCell.m
//  Awful
//
//  Created by Sean Berry on 2/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadCell.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulUser+AwfulMethods.h"
#import "AwfulThreadListController.h"
#import "AwfulSettings.h"

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

-(id) init {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AwfulThreadCell"];
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self=[super initWithCoder:aDecoder])) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(openThreadlistOptions:)];
        [self addGestureRecognizer:press];
    }
    return self;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    
    //self.backgroundColor =  [AwfulThreadCell backgroundColor];
    //self.contentView.backgroundColor = [AwfulThreadCell backgroundColor];
    
    /*
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
     */
}

-(void)configureForThread:(AwfulThread *)thread
{
    self.thread = thread;
    
    self.indentationLevel = 0;
    
    self.textLabel.text = thread.title;
    self.textLabel.numberOfLines = 3;
    self.textLabel.adjustsFontSizeToFitWidth = YES;
    self.textLabel.font = [[self class] textLabelFont];
    self.textLabel.textColor = [[self class] textColor];
    self.textLabel.backgroundColor = [(AwfulThreadCell*)[self class] backgroundColor];
    

    //int posts_per_page = [AwfulUser currentUser].postsPerPageValue;
    //int total_pages = (([thread.totalReplies intValue]-1)/posts_per_page) + 1;
    self.detailTextLabel.text = [NSString stringWithFormat:@"%@\r\nKilled by %@ [date]", thread.authorName, thread.lastPostAuthorName];
    self.detailTextLabel.font = [[self class] detailLabelFont];
    self.detailTextLabel.numberOfLines = 2;
    self.detailTextLabel.textColor = [[self class] textColor];
    self.detailTextLabel.backgroundColor = [(AwfulThreadCell*)[self class] backgroundColor];
    
    if (thread.totalUnreadPosts.intValue >= 0) {
        self.badgeString = thread.totalUnreadPosts.stringValue;
        self.badgeColor = [UIColor colorWithRed:0 green:.4 blue:.6 alpha:1];
        
        self.badge.alpha = (thread.totalUnreadPostsValue == 0)? 0.5 : 1.0;
    }
    else {
        self.badgeString = nil;
    }
    
    //author
    //replies
    //killed
    
    
    
    self.contentView.backgroundColor = [(AwfulThreadCell*)[self class] backgroundColor];
    self.backgroundColor = [(AwfulThreadCell*)[self class] backgroundColor];
    
    [self.tagLabel removeFromSuperview];
    
    [self configureTagImage];
        
    
    double rating = self.thread.threadRating.doubleValue;
    
    if (rating >= 1) {
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


    self.contentView.alpha = thread.isLockedValue? 0.5 : 1.0;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willLoadThreadPage:)
                                                 name:AwfulPageWillLoadNotification 
                                               object:self.thread];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didLoadThreadPage:)
                                                 name:AwfulPageDidLoadNotification 
                                               object:self.thread];

}

-(void) configureTagImage {
    NSURL *tag_url = [self.thread firstIconURL];
    if(tag_url != nil) {
        UIImage *img = [UIImage imageNamed:[tag_url lastPathComponent]];
        CGImageRef ref = img.CGImage;
        UIImage *scaled = [UIImage imageWithCGImage:ref scale:2 orientation:(UIImageOrientationUp)];
        
        self.imageView.image = scaled;
        self.imageView.layer.borderWidth = 1;
        self.imageView.layer.borderColor = [[UIColor blackColor] CGColor];
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
    
    NSURL *second_url = [self.thread secondIconURL];
    if(second_url != nil) {
        self.secondTagImage.frame = CGRectMake(self.imageView.foX-1, self.imageView.foY-1, 
                                               self.secondTagImage.fsW, self.secondTagImage.fsH);
        self.secondTagImage.hidden = NO;
        [self.secondTagImage setImage:[UIImage imageNamed:[second_url lastPathComponent]]];
    }


    //self.secondTagImage.hidden = YES;
}

-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread
{
    float offwhite = 241.0/255;
    UIColor *back_color = [UIColor colorWithWhite:offwhite alpha:1.0];
    
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
                                    initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleWhite)
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

+(CGFloat) heightForContent:(AwfulThread*)thread inTableView:(UITableView*)tableView {
    int width = tableView.frame.size.width - 65 - ((thread.totalUnreadPostsValue>0)? 50 : 0);
    
    CGSize textSize = {0, 0};
    CGSize detailSize = {0, 0};
    int height = 44;
    
    textSize = [thread.title sizeWithFont:self.textLabelFont
                      constrainedToSize:CGSizeMake(width, 4000) 
                          lineBreakMode:UILineBreakModeWordWrap];

        detailSize = [thread.title sizeWithFont:self.detailLabelFont 
                            constrainedToSize:CGSizeMake(width, 4000) 
                                lineBreakMode:UILineBreakModeWordWrap];
    
    height = 20 + textSize.height + detailSize.height;
    
    return (MAX(height,70));
}

+ (UIColor *)textColor
{
    return [[AwfulSettings settings] darkTheme] ? [UIColor whiteColor] : [UIColor blackColor];
}

+ (UIColor *)backgroundColor
{
    return [[AwfulSettings settings] darkTheme] ? [UIColor darkGrayColor] : [UIColor whiteColor];
}

+ (UIFont *)textLabelFont
{
    return [UIFont systemFontOfSize:14];
}

+ (UIFont *)detailLabelFont
{
    return [UIFont systemFontOfSize:10];
}

@end
