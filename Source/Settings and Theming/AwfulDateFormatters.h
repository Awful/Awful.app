//
//  AwfulDateFormatters.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-25.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// Data-specific date formatters that appear on many screens.
@interface AwfulDateFormatters : NSObject

// Singleton instance.
+ (instancetype)formatters;

@property (readonly, nonatomic) NSDateFormatter *postDateFormatter;
@property (readonly, nonatomic) NSDateFormatter *regDateFormatter;

@end
