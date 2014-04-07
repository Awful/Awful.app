//  AwfulForumCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulForumCell represents a forum in a table view.
 */
@interface AwfulForumCell : UITableViewCell

/**
 * A forum cell can have a disclosure button to show or hide the represented forum's subforums.
 *
 * The disclosureButton's `selected` property is YES when subforums are revealed, and is NO (the default) otherwise.
 *
 * The disclosureButton's `hidden` property is NO when the forum has subforums, and is YES (the default) otherwise.
 */
@property (readonly, strong, nonatomic) UIButton *disclosureButton;

/**
 * A label to display the name of the forum. Inherited from UITableViewCell.
 */
@property (readonly, strong, nonatomic) UILabel *textLabel;

/**
 * A forum cell can show a favorite button to add the forum to the user's favorites.
 *
 * The favoriteButton's `hidden` property is NO (the default) when the forum is not a favorite, and is YES otherwise.
 */
@property (readonly, strong, nonatomic) UIButton *favoriteButton;

/**
 * How deep the forum is in the hierarchy. Set to the number of forums above the cell's forum in the hierarchy.
 */
@property (assign, nonatomic) NSInteger subforumLevel;

@end
