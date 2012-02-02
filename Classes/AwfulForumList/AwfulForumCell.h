//
//  AwfulForumCell.h
//  Awful
//
//  Created by Regular Berry on 6/16/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulForumSection;
@class AwfulForumsList;

@interface AwfulForumCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *title;
@property (nonatomic, strong) IBOutlet UIButton *star;
@property (nonatomic, strong) IBOutlet UIButton *arrow;
@property (nonatomic, strong) AwfulForumSection *section;
@property (nonatomic, weak) AwfulForumsList *forumsList;

-(IBAction)tappedArrow : (id)sender;
-(IBAction)tappedStar : (id)sender;

@end
