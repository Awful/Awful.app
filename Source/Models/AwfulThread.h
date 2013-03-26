//
//  AwfulThread.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "_AwfulThread.h"

@interface AwfulThread : _AwfulThread

@property (readonly, nonatomic) NSString *firstIconName;
@property (readonly, nonatomic) NSString *secondIconName;

@property (readonly, nonatomic) BOOL beenSeen;

+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos;

+ (NSArray *)threadsCreatedOrUpdatedWithJSON:(NSDictionary *)json;

+ (instancetype)firstOrNewThreadWithThreadID:(NSString *)threadID;

@end


typedef enum {
    AwfulStarCategoryOrange = 0,
    AwfulStarCategoryRed,
    AwfulStarCategoryYellow,
    AwfulStarCategoryNone
} AwfulStarCategory;
