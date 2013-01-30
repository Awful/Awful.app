#import "_AwfulLeper.h"

@interface AwfulLeper : _AwfulLeper {}

+ (NSArray*)lepersCreatedOrUpdatedWithParsedInfo:(NSArray*) info;

@end

typedef enum {
    AwfulLeperProbation,
    AwfulLeperBan,
    AwfulLeperPermaban
} AwfulLeperType;