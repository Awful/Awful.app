#import "_AwfulLogEntry.h"

typedef enum {
    AwfulLogLevelInfo,
    AwfulLogLevelWarning,
    AwfulLogLevelError
} AwfulLogLevel;

@interface AwfulLogEntry : _AwfulLogEntry {}
+(void) writeLogEntryWithLevel:(AwfulLogLevel)level category:(NSString*) category message:(NSString*)message;
@end


