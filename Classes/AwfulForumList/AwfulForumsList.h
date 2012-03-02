//
//  AwfulForumsList.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulForum;
@class AwfulForumCell;
@class AwfulForumHeader;
@class AwfulSplitViewController;

@interface AwfulForumSection : NSObject

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, strong) NSMutableArray *children;
@property BOOL expanded;
@property NSUInteger rowIndex;
@property NSUInteger totalAncestors;

+(AwfulForumSection *)sectionWithForum : (AwfulForum *)forum;

@end

@interface AwfulForumsList : UITableViewController <UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *favorites;
@property (nonatomic, strong) NSMutableArray *forums;
@property (nonatomic, strong) NSMutableArray *forumSections;
@property (nonatomic, strong) IBOutlet AwfulForumCell *forumCell;
@property (nonatomic, strong) IBOutlet AwfulForumHeader *headerView;
@property (nonatomic, strong) IBOutlet UITableViewCell *refreshCell;

-(void)loadFavorites;
-(void)saveFavorites;
-(BOOL)isAwfulForumSectionFavorited : (AwfulForumSection *)section;
-(void)toggleFavoriteForForumSection : (AwfulForumSection *)section;

-(void)hitDone;

-(IBAction)grabFreshList;
-(void)saveForums;
-(void)loadForums;
-(void)toggleExpandForForumSection : (AwfulForumSection *)section;

-(void)addForumToSectionTree : (AwfulForum *)forum;
-(AwfulForumSection *)getForumSectionAtSection : (NSUInteger)section_index;
-(NSUInteger)getSectionForForumSection : (AwfulForumSection *)forum_section;
-(AwfulForum *)getForumAtIndexPath : (NSIndexPath *)path;
-(NSIndexPath *)getIndexPathForSection : (AwfulForumSection *)section;
-(AwfulForumSection *)getForumSectionAtIndexPath : (NSIndexPath *)path;
-(NSMutableArray *)getVisibleDescendantsListForForumSection : (AwfulForumSection *)section;
-(AwfulForumSection *)getForumSectionFromID : (NSString *)forum_id;
-(AwfulForumSection *)getForumSectionFromID : (NSString *)forum_id lookInForumSection : (AwfulForumSection *)section;
-(AwfulForumSection *)getRootSectionForSection : (AwfulForumSection *)section;

@end

@interface AwfulForumsListIpad : AwfulForumsList

-(void)hitBookmarks;

@end
