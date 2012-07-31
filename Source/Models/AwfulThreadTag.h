#import "_AwfulThreadTag.h"

@interface AwfulThreadTag : _AwfulThreadTag {}

+(NSArray*)parseThreadTagsWithData : (NSData *)data;
+(void) cacheThreadTag:(AwfulThreadTag*)emote data:(NSData*)data ;
@end
