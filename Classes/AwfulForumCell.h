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

@interface AwfulLineDrawer : UIView {
    int _totalAncestors;
}

@property (nonatomic, assign) int totalAncestors;

@end

@interface AwfulForumCell : UITableViewCell {
    UILabel *_title;
    UIButton *_star;
    UIButton *_arrow;
    AwfulForumSection *_section;
    AwfulLineDrawer *_line;
    AwfulForumsList *_delegate;
}

@property (nonatomic, retain) IBOutlet UILabel *title;
@property (nonatomic, retain) IBOutlet UIButton *star;
@property (nonatomic, retain) IBOutlet UIButton *arrow;
@property (nonatomic, retain) AwfulForumSection *section;
@property (nonatomic, retain) IBOutlet AwfulLineDrawer *line;
@property (nonatomic, assign) AwfulForumsList *delegate;

-(IBAction)tappedArrow : (id)sender;
-(IBAction)tappedStar : (id)sender;

@end
