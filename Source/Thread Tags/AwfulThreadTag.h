//  AwfulThreadTag.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

@interface AwfulThreadTag : NSObject <NSCoding>

@property (copy, nonatomic) NSString *imageName;
@property (copy, nonatomic) NSString *composeID;

+ (NSString *)emptyThreadTagImageName;
+ (NSString *)emptyPrivateMessageTagImageName;

@end
