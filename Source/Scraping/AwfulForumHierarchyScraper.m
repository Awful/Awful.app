//  AwfulForumHierarchyScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumHierarchyScraper.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"

@interface AwfulForumHierarchyScraper ()

@property (copy, nonatomic) NSArray *categories;

@end

@implementation AwfulForumHierarchyScraper

#pragma mark - AwfulDocumentScraper

- (void)scrape
{
    // There's a pulldown menu at the bottom of forumdisplay.php and showthread.php that has (among other things) a depth-first traversal of the category/forum hierarchy:
    //
    // ```
    // <select name="forumid">
    //   <option value="-1">Whatever</option>
    //   <option value="pm">Private Messages</option>
    //   ...
    //   <option value="-1">--------------------</option>
    //   <option value="48"> Main</option>
    //   <option value="1">-- General Bullshit</option>
    //   <option value="155">---- SA's Front Page Discussion</option>
    //   ...
    // </select>
    // ```
    //
    // It includes arbitrarily-nested subforums (unlike index.php, which only goes to the subforum level), but excludes permissions-based forums. It's as close as we can get to an exhaustive, hierarchical list of all accessible forums.
    NSMutableArray *categories = [NSMutableArray new];
    NSMutableArray *forumStack = [NSMutableArray new];
    int32_t forumIndex = 0;
    NSArray *options = [self.node awful_nodesMatchingCachedSelector:@"select[name = 'forumid'] option"];
    for (HTMLElement *option in options) {
        NSString *itemID = option[@"value"];
        if (itemID.integerValue <= 0) continue;
        AwfulScanner *scanner = [AwfulScanner scannerWithString:option.innerHTML];
        NSUInteger depth = 0;
        while ([scanner scanString:@"--" intoString:nil]) {
            depth++;
        }
        while (depth > 0 && forumStack.count >= depth) {
            [forumStack removeLastObject];
        }
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
        NSString *itemName = [[scanner.string substringFromIndex:scanner.scanLocation] gtm_stringByUnescapingFromHTML];
        if (depth == 0) {
            AwfulCategory *category = [AwfulCategory firstOrNewCategoryWithCategoryID:itemID inManagedObjectContext:self.managedObjectContext];
            if (itemName.length > 0) {
                category.name = itemName;
            }
            category.index = (int32_t)categories.count;
            [categories addObject:category];
        } else {
            AwfulForum *forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:self.managedObjectContext withID:itemID];
            if (itemName.length > 0) {
                forum.name = itemName;
            }
            forum.category = categories.lastObject;
            forum.parentForum = forumStack.lastObject;
            forum.index = forumIndex++;
            [forumStack addObject:forum];
        }
    }
    self.categories = categories;
}

@end
