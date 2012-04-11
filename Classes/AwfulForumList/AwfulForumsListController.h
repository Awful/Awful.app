//
//  AwfulForumsList.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulTableViewController.h"

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
-(void)setAllExpanded;

@end

@interface AwfulForumsListController : AwfulTableViewController <UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *favorites;
@property (nonatomic, strong) NSMutableArray *forums;
@property (nonatomic, strong) NSMutableArray *forumSections;
@property (nonatomic, strong) IBOutlet AwfulForumHeader *headerView;
@property (nonatomic, strong) IBOutlet UISegmentedControl *segmentedControl;
@property BOOL displayingFullList;

-(void)loadFavorites;
-(void)toggleFavoriteForForum : (AwfulForum *)forum;

-(void)loadForums;
-(void)hitDone;
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

-(IBAction)segmentedControlChanged:(id)sender;

@end

