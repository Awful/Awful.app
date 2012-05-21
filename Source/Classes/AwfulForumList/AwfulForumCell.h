//
//  AwfulForumCell.h
//  Awful
//
//  Created by Regular Berry on 6/16/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulForumSection;
@class AwfulForumsListController;

@interface AwfulForumCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UIButton *arrow;
@property (nonatomic, strong) AwfulForumSection *section;
@property (nonatomic, weak) AwfulForumsListController *forumsList;

-(IBAction)tappedArrow : (id)sender;

@end
