//  AwfulFavoriteForumCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulFavoriteForumCell represents a forum in the "Favorites" section of a table view.
 */
@interface AwfulFavoriteForumCell : UITableViewCell

/**
 * Returns an initialized AwfulFavoriteForumCell. This is the designated initializer.
 *
 * @param reuseIdentifier A string used by the table view to identify the cell for reuse.
 */
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@end
