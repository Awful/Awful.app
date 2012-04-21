//
//  AwfulSettings.h
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulSettings : NSObject

// Singleton instance.
+ (AwfulSettings *)settings;

- (void)registerDefaults;

@end
