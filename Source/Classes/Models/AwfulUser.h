//
//  AwfulUser.h
//  Awful
//
//  Created by Sean Berry on 3/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface AwfulUser : NSManagedObject

@property (nonatomic, retain) NSString * userName;
@property (nonatomic, retain) NSString * userID;
@property (nonatomic, retain) NSNumber * postsPerPage;

@end
