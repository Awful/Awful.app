//  AwfulExpandingSplitViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

/**
 * AwfulExpandingSplitViewController was the split view controller as of Awful 2.0, which introduced state preservation and restoration. As of 2.0.4, Awful uses AwfulSplitViewController instead. However, UIKit's state restoration will not call -decodeRestorableStateWithCoder: if the encoded class doesn't match the decoded class. In an effort to preserve state restoration data when upgrading from 2.0.3 to 2.0.4, we maintain this class hierarchy.
 *
 * By all means delete this otherwise pointless class once you're confident that all users of 2.0.3 have upgraded to 2.0.4 (or are apathetic about their plight).
 *
 * I fell back to this after none of -[NSKeyedUnarchiver setClass:forClassName:], +[NSKeyedUnarchiver setClass:forClassName:], or -[NSKeyedUnarchiverDelegate unarchiver:cannotDecodeObjectOfClassName:originalClasses:] helped on any of the UIStateRestorationKeyedUnarchiver instances I could reach during state restoration.
 *
 * rdar://16079570
 */
@interface AwfulExpandingSplitViewController : AwfulViewController

@end
