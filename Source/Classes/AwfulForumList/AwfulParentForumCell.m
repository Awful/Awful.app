//
//  AwfulParentForumCell.m
//  Awful
//
//  Created by me on 6/27/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParentForumCell.h"
#import "AwfulForum.h"

@implementation AwfulParentForumCell
@synthesize isExpanded = _isExpanded;

- (id)init
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AwfulParentForumCell"];
    if (self) {
        
    }
    return self;
}

-(void) awakeFromNib {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggle)];
    [self.imageView addGestureRecognizer:tap];
    
}

-(void) toggle {
    _isExpanded = !_isExpanded;
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:self.isExpanded]
                                                                                  forKey:@"toggle"
                              ];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulToggleExpandForum                                                          
                                                        object:self
                                                      userInfo:userInfo];
    
    
}

-(void) setForum:(AwfulForum *)forum {
    self.textLabel.text = forum.name;
    self.textLabel.adjustsFontSizeToFitWidth = YES;
    self.detailTextLabel.text = forum.desc;
    self.detailTextLabel.numberOfLines = 0;
    self.isExpanded = forum.expandedValue;
    self.imageView.image = [UIImage imageNamed:@"forum-arrow-right.png"];
    self.textLabel.font = [UIFont boldSystemFontOfSize:18];
    self.textLabel.font = [UIFont boldSystemFontOfSize:16];
    self.indentationLevel = 0;
    
    if (forum.parentForum != nil) {
        self.indentationLevel = 2;
        self.textLabel.font = [UIFont boldSystemFontOfSize:15];
        self.textLabel.font = [UIFont boldSystemFontOfSize:14];
        self.detailTextLabel.text = forum.parentForum.name;
        self.imageView.image = nil;
    }
}

@end
