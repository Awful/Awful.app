//
//  AwfulForum.h
//  Awful
//
//  Created by Sean Berry on 3/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AwfulForum;

@interface AwfulForum : NSManagedObject

@property (nonatomic, retain) NSString * forumID;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * index;
@property (nonatomic, retain) AwfulForum *parentForum;

@end
