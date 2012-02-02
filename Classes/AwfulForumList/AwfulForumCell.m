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
#define PI_OVER_2 (3.14159f / 2.0f)

@implementation AwfulForumCell

@synthesize title, star, arrow, section, forumsList;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)setSection:(AwfulForumSection *)aSection
{
    section = aSection;
    
    if(self.section != nil) {
        
        self.title.text = self.section.forum.name;
        
        if([section.children count] == 0) {
            [self.arrow removeFromSuperview];
        } else {
            [self addSubview:self.arrow];
        }
        
        if(section.expanded) {
            self.arrow.transform = CGAffineTransformMakeRotation(PI_OVER_2);
        } else {
            self.arrow.transform = CGAffineTransformIdentity;
        }
        
        if(section.totalAncestors > 1) {
            self.arrow.center = CGPointMake(LINE_SPACE*3, self.arrow.center.y);
        } else {
            self.arrow.center = CGPointMake(LINE_SPACE*2, self.arrow.center.y);
        }
        
        if([self.forumsList isAwfulForumSectionFavorited:section]) {
            [self.star setImage:[UIImage imageNamed:@"star_on.png"] forState:UIControlStateNormal];
        } else {
            [self.star setImage:[UIImage imageNamed:@"star_off.png"] forState:UIControlStateNormal];
        }
    }
}

-(IBAction)tappedArrow : (id)sender
{
    [self.forumsList toggleExpandForForumSection:self.section];
}

-(IBAction)tappedStar : (id)sender
{
    [self.forumsList toggleFavoriteForForumSection:self.section];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    if(editing) {
        [self.star removeFromSuperview];
    } else {
        [self addSubview:self.star];
    }
}

@end
