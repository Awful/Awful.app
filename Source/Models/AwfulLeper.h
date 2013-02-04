#import "_AwfulLeper.h"

@interface AwfulLeper : _AwfulLeper {}

+ (NSArray*)lepersCreatedOrUpdatedWithParsedInfo:(NSArray*) info;

@end

typedef enum {
    AwfulLeperTypeUnknown = -1,
    AwfulLeperTypeProbation,
    AwfulLeperTypeAutoban,
    AwfulLeperTypeBan,
    AwfulLeperTypePermaban
} AwfulLeperType;