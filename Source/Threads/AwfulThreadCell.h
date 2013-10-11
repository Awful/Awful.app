//  AwfulThreadCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
#import "AwfulThreadTagAndRatingView.h"

/**
 * An AwfulThreadCell represents a thread in a table view.
 */
@interface AwfulThreadCell : UITableViewCell

/**
 * Returns an initialized AwfulThreadCell. This is the designated initializer.
 *
 * @param reuseIdentifier A string used by the table view to identify the cell for reuse.
 */
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

/**
 * An AwfulThreadTagAndRatingView suitable for displaying the thread's tag and, optionally, its rating.
 */
@property (readonly, strong, nonatomic) AwfulThreadTagAndRatingView *tagAndRatingView;

/**
 * A label displaying the thread's title. Inherited from UITableViewCell.
 */
@property (readonly, strong, nonatomic) UILabel *textLabel;

/**
 * A label displaying the number of pages in the thread.
 */
@property (readonly, strong, nonatomic) UILabel *numberOfPagesLabel;

/**
 * A label displaying additional information about the thread. Inherited from UITableViewCell.
 */
@property (readonly, strong, nonatomic) UILabel *detailTextLabel;

/**
 * A badge on the right of the cell, perhaps for showing the number of unread posts in the thread.
 */
@property (readonly, strong, nonatomic) UILabel *badgeLabel;

/**
 * An image view on the top right of the cell, for indicating a sticky thread.
 */
@property (readonly, strong, nonatomic) UIImageView *stickyImageView;

@end
