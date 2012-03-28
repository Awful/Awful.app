//
//  AwfulForumCell.m
//  Awful
//
//  Created by Regular Berry on 6/16/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumCell.h"
#import "AwfulForumsListController.h"
#import "AwfulForum.h"

#define LINE_SPACE 10
#define PI_OVER_2 (3.14159f / 2.0f)

@implementation AwfulForumCell

@synthesize titleLabel = _titleLabel;
@synthesize arrow = _arrow;
@synthesize section = _section;
@synthesize forumsList = _forumsList;

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
    _section = aSection;
    
    if(_section != nil) {
        
        self.titleLabel.text = self.section.forum.name;
        
        if([_section.children count] == 0) {
            [self.arrow removeFromSuperview];
        } else {
            [self addSubview:self.arrow];
        }
        
        if(_section.expanded) {
            [self.arrow setImage:[UIImage imageNamed:@"forum-arrow-down.png"] forState:UIControlStateNormal];
        } else {
            [self.arrow setImage:[UIImage imageNamed:@"forum-arrow-right.png"] forState:UIControlStateNormal];
        }
        
        if(_section.totalAncestors > 1) {
            self.arrow.center = CGPointMake(LINE_SPACE*3, self.arrow.center.y);
        } else {
            self.arrow.center = CGPointMake(LINE_SPACE*2, self.arrow.center.y);
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

@end
