//
//  AwfulForumCell.m
//  Awful
//
//  Created by Regular Berry on 6/16/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumCell.h"
#import "AwfulForumsList.h"
#import "AwfulForum.h"

#define LINE_SPACE 10

@implementation AwfulForumHeader

@synthesize title = _title;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self=[super initWithCoder:aDecoder])) {
        
    }
    return self;
}

-(void)dealloc
{
    [_title release];
    [super dealloc];
}

@end

@implementation AwfulForumCell

@synthesize title = _title;
@synthesize star = _star;
@synthesize arrow = _arrow;
@synthesize section = _section;
@synthesize delegate = _delegate;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)dealloc
{
    [_title release];
    [_star release];
    [_arrow release];
    [super dealloc];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)setSection:(AwfulForumSection *)section
{
    if(section != _section) {
        [_section release];
        _section = [section retain];
    }
    
    if(section != nil) {
        
        self.title.text = section.forum.name;
        
        if([section.children count] == 0) {
            [self.arrow removeFromSuperview];
        } else {
            [self addSubview:self.arrow];
        }
        
        if(section.expanded) {
            self.arrow.transform = CGAffineTransformMakeRotation(3.14159/2);
        } else {
            self.arrow.transform = CGAffineTransformIdentity;
        }
        
        if(section.totalAncestors > 1) {
            self.arrow.center = CGPointMake(LINE_SPACE*3, self.arrow.center.y);
        } else {
            self.arrow.center = CGPointMake(LINE_SPACE*2, self.arrow.center.y);
        }
        
        if([self.delegate isAwfulForumSectionFavorited:section]) {
            [self.star setImage:[UIImage imageNamed:@"star_on.png"] forState:UIControlStateNormal];
        } else {
            [self.star setImage:[UIImage imageNamed:@"star_off.png"] forState:UIControlStateNormal];
        }
    }
}

-(IBAction)tappedArrow : (id)sender
{
    [self.delegate toggleExpandForForumSection:self.section];
}

-(IBAction)tappedStar : (id)sender
{
    [self.delegate toggleFavoriteForForumSection:self.section];
}

@end
