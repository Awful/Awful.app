//  AwfulCategory.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulModels.h"

/**
 * An AwfulCategory is the topmost level of the forum hierarchy.
 */
@interface AwfulCategory : AwfulManagedObject

/**
 * The parameter in a URL like `http://forums.somethingawful.com/forumdisplay.php?forumid=48`.
 */
@property (copy, nonatomic) NSString *categoryID;

/**
 * Where the category is shown on the big forum list (`http://forums.somethingawful.com`), starting with 0.
 */
@property (assign, nonatomic) int32_t index;

/**
 * The name of the category, like "Main" or "Discussion".
 */
@property (copy, nonatomic) NSString *name;

/**
 * A set of AwfulForum objects of all forums and subforums below the category in the hierarchy.
 */
@property (copy, nonatomic) NSSet *forums;

@end
