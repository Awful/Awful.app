//
//  AwfulThreadCell.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>
#import "AwfulBadgeView.h"

@interface AwfulThreadCell : UITableViewCell

// Designated initializer.
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property (nonatomic) UIImage *icon;
@property (nonatomic) UIImage *secondaryIcon;
@property (nonatomic) CGFloat iconAlpha;

@property (readonly, weak, nonatomic) UIImageView *stickyImageView;

@property (nonatomic) CGSize stickyImageViewOffset;

@property (nonatomic) CGFloat rating;

@property (readonly, weak, nonatomic) UIImageView *ratingImageView;

@property (getter=isClosed, nonatomic) BOOL closed;

@property (readonly, weak, nonatomic) UILabel *originalPosterTextLabel;

@property (readonly, weak, nonatomic) AwfulBadgeView *unreadCountBadgeView;

@property (nonatomic) BOOL showsUnread;

@end
