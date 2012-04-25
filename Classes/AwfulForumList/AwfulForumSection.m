//
//  AwfulForumSection.m
//  Awful
//
//  Created by Nolan Waite on 12-04-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumSection.h"
#import "AwfulForum.h"

@implementation AwfulForumSection

@synthesize forum = _forum;
@synthesize children = _children;
@synthesize expanded = _expanded;
@synthesize rowIndex = _rowIndex;
@synthesize totalAncestors = _totalAncestors;

- (id)init
{
    self = [super init];
    if (self) {
        self.children = [[NSMutableArray alloc] init];
        self.rowIndex = NSNotFound;
    }
    return self;
}

+ (AwfulForumSection *)sectionWithForum:(AwfulForum *)forum
{
    AwfulForumSection *sec = [[AwfulForumSection alloc] init];
    sec.forum = forum;
    return sec;
}

- (void)setAllExpanded
{
    self.expanded = YES;
    [self.children makeObjectsPerformSelector:@selector(setAllExpanded)];
}

@end
