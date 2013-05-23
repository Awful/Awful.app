//
//  AwfulThreadTag.h
//  Awful
//
//  Created by Nolan Waite on 2013-05-22.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulThreadTag : NSObject

@property (copy, nonatomic) NSString *imageName;
@property (copy, nonatomic) NSString *composeID;

+ (NSString *)emptyThreadTagImageName;
+ (NSString *)emptyPrivateMessageTagImageName;

@end
