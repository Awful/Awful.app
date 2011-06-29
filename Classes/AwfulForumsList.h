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

@interface AwfulForumSection : NSObject
{
    AwfulForum *_forum;
    NSMutableArray *_children;
    BOOL _expanded;
    NSUInteger _rowIndex;
    NSUInteger _totalAncestors;
}

@property (nonatomic, retain) AwfulForum *forum;
@property (nonatomic, retain) NSMutableArray *children;
@property BOOL expanded;
@property NSUInteger rowIndex;
@property NSUInteger totalAncestors;

+(AwfulForumSection *)sectionWithForum : (AwfulForum *)forum;

@end

@interface AwfulForumsList : UITableViewController <UIAlertViewDelegate> {
    NSMutableArray *_favorites;
    NSMutableArray *_forums;
    NSMutableArray *_forumSections;
    AwfulForumCell *_forumCell;
    AwfulForumHeader *_headerView;
    UITableViewCell *_refreshCell;
}

@property (nonatomic, retain) NSMutableArray *favorites;
@property (nonatomic, retain) NSMutableArray *forums;
@property (nonatomic, retain) NSMutableArray *forumSections;
@property (nonatomic, retain) IBOutlet AwfulForumCell *forumCell;
@property (nonatomic, retain) IBOutlet AwfulForumHeader *headerView;
@property (nonatomic, retain) IBOutlet UITableViewCell *refreshCell;

-(void)loadFavorites;
-(void)saveFavorites;
-(BOOL)isAwfulForumSectionFavorited : (AwfulForumSection *)section;
-(void)toggleFavoriteForForumSection : (AwfulForumSection *)section;

-(void)hitDone;

-(IBAction)grabFreshList;
-(void)saveForums;
-(void)loadForums;
-(void)toggleExpandForForumSection : (AwfulForumSection *)section;
-(BOOL)isRefreshSection : (NSIndexPath *)indexPath;

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
