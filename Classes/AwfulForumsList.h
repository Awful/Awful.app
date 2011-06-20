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

@end

@interface AwfulForumsList : UITableViewController <UIAlertViewDelegate> {
    NSMutableArray *_favorites;
    NSMutableArray *_forums;
    NSMutableArray *_forumSections;
    AwfulForum *_goldmine;
    AwfulForumCell *_forumCell;
}

@property (nonatomic, retain) NSMutableArray *favorites;
@property (nonatomic, retain) NSMutableArray *forums;
@property (nonatomic, retain) NSMutableArray *forumSections;
@property (nonatomic, retain) AwfulForum *goldmine;
@property (nonatomic, retain) IBOutlet AwfulForumCell *forumCell;

-(void)signOut;
-(void)makeFavorite : (UIButton *)sender;
-(void)removeFavorite : (UIButton *)sender;

-(void)updateSignedIn;
-(void)hitDone;

-(void)grabFreshList;

-(void)toggleForumSection : (AwfulForumSection *)section;
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
