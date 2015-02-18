//  AwfulForumHierarchyScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumHierarchyScraper.h"
#import "AwfulScanner.h"
#import <AwfulCore/AwfulCore-Swift.h>

@interface AwfulForumHierarchyScraper ()

@property (copy, nonatomic) NSArray *forums;

@end

@implementation AwfulForumHierarchyScraper

#pragma mark - AwfulDocumentScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
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
    
    // We'll do one pass to find all the item IDs that we need, then do a couple batch fetches for the stuff we already know about. Then we'll do another pass to update or insert the model objects.
    NSMutableArray *infoDictionaries = [NSMutableArray new];
    NSMutableArray *groupKeys = [NSMutableArray new];
    NSMutableArray *forumKeys = [NSMutableArray new];
    NSArray *options = [self.node nodesMatchingSelector:@"select[name='forumid'] option"];
    for (HTMLElement *option in options) {
        NSString *itemID = option[@"value"];
        if (itemID.integerValue <= 0) continue;
        
        NSMutableDictionary *info = [NSMutableDictionary new];
        info[@"itemID"] = itemID;
        AwfulScanner *scanner = [AwfulScanner scannerWithString:option.textContent];
        NSUInteger depth = 0;
        while ([scanner scanString:@"--" intoString:nil]) {
            depth++;
        }
        info[@"depth"] = @(depth);
        if (depth == 0) {
            [groupKeys addObject:[[ForumGroupKey alloc] initWithGroupID:itemID]];
        } else {
            [forumKeys addObject:[[ForumKey alloc] initWithForumID:itemID]];
        }
        
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
        NSString *itemName = [scanner.string substringFromIndex:scanner.scanLocation];
        if (itemName.length > 0) {
            info[@"itemName"] = itemName;
        }
        
        [infoDictionaries addObject:info];
    }
    NSArray *groups = [ForumGroup objectsForKeys:groupKeys inManagedObjectContext:self.managedObjectContext];
    NSArray *forums = [Forum objectsForKeys:forumKeys inManagedObjectContext:self.managedObjectContext];
    NSMutableArray *forumStack = [NSMutableArray new];
    int32_t groupIndex = 0;
    int32_t forumIndex = 0;
    ForumGroup *group;
    for (NSDictionary *info in infoDictionaries) {
        NSString *itemName = info[@"itemName"];
        NSUInteger depth = [info[@"depth"] unsignedIntegerValue];
        if (depth == 0) {
            group = groups[groupIndex];
            group.name = itemName;
            group.index = groupIndex++;
        } else {
            NSUInteger numberOfForumsToRemove = forumStack.count - depth + 1;
            [forumStack removeObjectsInRange:NSMakeRange(forumStack.count - numberOfForumsToRemove, numberOfForumsToRemove)];
            Forum *forum = forums[forumIndex];
            forum.metadata.visibleInForumList = depth == 1;
            forum.name = itemName;
            forum.group = group;
            forum.parentForum = forumStack.lastObject;
            forum.index = forumIndex++;
            [forumStack addObject:forum];
        }
    }
    self.forums = forums;
}

@end
