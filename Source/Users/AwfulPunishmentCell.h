//  AwfulPunishmentCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 * An AwfulInfractionCell details a probation or ban.
 */
@interface AwfulPunishmentCell : UITableViewCell

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
