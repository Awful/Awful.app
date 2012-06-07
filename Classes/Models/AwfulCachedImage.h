//
//  AwfulCachedImage.h
//  Awful
//
//  Created by me on 5/6/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface AwfulCachedImage : NSManagedObject

@property (nonatomic, retain) NSDate * cacheDate;
@property (nonatomic, retain) NSData * imageData;
@property (nonatomic, retain) NSString * urlString;

@end
