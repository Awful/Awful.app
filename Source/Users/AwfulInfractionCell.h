//  AwfulInfractionCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulInfractionCell details a probation or ban.
 */
@interface AwfulInfractionCell : UITableViewCell

/**
 * Returns an initialized AwfulInfractionCell. This is the designated initializer.
 *
 * @param reuseIdentifier A string used by a table view for reusing the cell.
 */
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

/**
 * A label that explains why the infraction occurred.
 */
@property (readonly, strong, nonatomic) UILabel *reasonLabel;

/**
 * Returns the height of a cell.
 *
 * @param banReason The reason for the ban that will be wrapped into several lines if necessary.
 * @param width     The width of the cell.
 */
+ (CGFloat)rowHeightWithBanReason:(NSString *)banReason width:(CGFloat)width;

@end
