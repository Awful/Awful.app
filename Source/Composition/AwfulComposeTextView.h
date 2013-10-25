//  AwfulComposeTextView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulComposeTextView is a text view suitable for composing replies, posts and private messages.
 */
@interface AwfulComposeTextView : UITextView

@end

/**
 * Images larger than RequiresThumbnailImageSize in either dimension should be thumbnailed.
 * "Keep all images smaller than **800 pixels horizontal and 600 pixels vertical.**"
 * http://www.somethingawful.com/d/forum-rules/forum-rules.php?page=2
 */
extern const CGSize RequiresThumbnailImageSize;
