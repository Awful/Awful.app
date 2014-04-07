//  AwfulPrivateMessageCell.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulPrivateMessageCell represents a private message in a table view.
 */
@interface AwfulPrivateMessageCell : UITableViewCell

/**
 * An image view laid over the bottom right corner of the thread tag.
 */
@property (readonly, strong, nonatomic) UIImageView *overlayImageView;

/**
 * Whether or not the thread tag is hidden.
 */
@property (assign, nonatomic) BOOL threadTagHidden;

@end
