//  UITableView+HideStuff.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UITableView (HideStuff)

/**
 * Causes the section headers not to stick to the top of a table view.
 *
 * Attempts to keep the headers hidden on iOS 7 with a transparent nav bar, but this may fail if section headers' heights are not uniform.
 */
- (void)awful_unstickSectionHeaders;

/**
 * Causes the table view not to show any cell separators after the last cell.
 */
- (void)awful_hideExtraneousSeparators;

@end
