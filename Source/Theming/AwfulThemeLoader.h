//  AwfulThemeLoader.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulTheme.h"

/**
 * An AwfulThemeLoader loads AwfulTheme objects from a file in the main bundle called "Themes.plist".
 */
@interface AwfulThemeLoader : NSObject

/**
 * Returns the default AwfulTheme, which has a light background and dark text.
 */
@property (readonly, strong, nonatomic) AwfulTheme *defaultTheme;

/**
 * Returns the named AwfulTheme object, or nil if there is no theme with the name.
 */
- (AwfulTheme *)themeNamed:(NSString *)themeName;

/**
 * Returns an array of AwfulTheme objects usable for the forum with the given ID.
 */
- (NSArray *)themesForForumWithID:(NSString *)forumID;

@end
