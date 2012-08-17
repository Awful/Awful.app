#import "_AwfulLogEntry.h"

typedef enum {
    AwfulLogLevelInfo,
    AwfulLogLevelWarning,
    AwfulLogLevelError
} AwfulLogLevel;

@interface AwfulLogEntry : _AwfulLogEntry {}
+(void) writeLogEntryWithLevel:(AwfulLogLevel)level category:(NSString*)category className:(NSString*)className message:(NSString*)message;
@end


@interface NSObject (AwfulLogEntry)
-(void) writeAwfulLogEntryWithLevel:(AwfulLogLevel)level category:(NSString*) category message:(NSString*)message;
+(void) writeLogEntryWithLevel:(AwfulLogLevel)level category:(NSString*) category message:(NSString*)message;
@end