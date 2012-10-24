//
//  AwfulThreadCell.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-02.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulBadgeView.h"

@interface AwfulThreadCell : UITableViewCell

// Designated initializer.
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property (nonatomic, getter=isSticky) BOOL sticky;

@property (nonatomic) CGFloat rating;

@property (getter=isClosed, nonatomic) BOOL closed;

@property (readonly, weak, nonatomic) UILabel *originalPosterTextLabel;

@property (readonly, weak, nonatomic) AwfulBadgeView *unreadCountBadgeView;

@property (nonatomic) BOOL showsUnread;

@end
