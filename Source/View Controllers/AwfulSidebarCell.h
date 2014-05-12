//  AwfulSidebarCell.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulSidebarCell acts as a tab in the basement.
 */
@interface AwfulSidebarCell : UITableViewCell

/**
 * Designated initializer.
 */
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

/**
 * The cell's accessory view, lazily created in the getter.
 */
@property (strong, nonatomic) UILabel *badgeLabel;

/**
 * Since UITableView on iOS 7 can't handle separators, here is our own.
 */
@property (readonly, strong, nonatomic) UIView *separatorView;

@end
