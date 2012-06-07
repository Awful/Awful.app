//
//  AwfulForumSection.h
//  Awful
//
//  Created by Nolan Waite on 12-04-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulForum;

@interface AwfulForumSection : NSObject

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, strong) NSMutableArray *children;
@property BOOL expanded;
@property NSUInteger rowIndex;
@property NSUInteger totalAncestors;

+ (AwfulForumSection *)sectionWithForum:(AwfulForum *)forum;
-(void)setAllExpanded;

@end
