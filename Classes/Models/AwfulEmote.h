//
//  AwfulEmote.h
//  Awful
//
//  Created by me on 5/6/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "AwfulCachedImage.h"


@interface AwfulEmote : AwfulCachedImage

@property (nonatomic, retain) NSString * code;
@property (nonatomic, retain) NSString * desc;

@end
