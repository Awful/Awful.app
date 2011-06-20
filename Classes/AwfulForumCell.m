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

@implementation AwfulLineDrawer

@synthesize totalAncestors = _totalAncestors;
/*
-(void)drawRect:(CGRect)rect
{    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGColorRef black = [UIColor blackColor].CGColor;
    CGContextSetStrokeColorWithColor(context, black);
    
    if(self.totalAncestors >= 2) {
        CGContextBeginPath(context);
        int ancestors = self.totalAncestors;
        int x_value = LINE_SPACE*2;
        while(ancestors >= 2) {
            CGContextMoveToPoint(context, x_value, 0);
            CGContextAddLineToPoint(context, x_value, rect.size.height);
            x_value += LINE_SPACE;
            ancestors--;
        }
        CGContextStrokePath(context);
    }
}*/

@end

@implementation AwfulForumCell

@synthesize title = _title;
@synthesize star = _star;
@synthesize arrow = _arrow;
@synthesize section = _section;
@synthesize line = _line;
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
    [_line release];
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
        self.title.text = section.forum.name;
        if([section.children count] == 0) {
            [self.arrow removeFromSuperview];
        }
        if(section.expanded) {
            self.arrow.transform = CGAffineTransformMakeRotation(3.14159/2);
        }
        self.line.totalAncestors = section.totalAncestors;
        if(section.totalAncestors > 1) {
            self.arrow.frame = CGRectOffset(self.arrow.frame, LINE_SPACE, 0);
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
