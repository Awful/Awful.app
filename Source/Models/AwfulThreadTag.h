#import "_AwfulThreadTag.h"

@interface AwfulThreadTag : _AwfulThreadTag {}

+(NSArray*)parseThreadTagsForForum:(AwfulForum*)forum withData : (NSData *)data;
+(void) cacheThreadTag:(AwfulThreadTag*)emote data:(NSData*)data ;
@property (nonatomic,readonly) UIImage* image;
@end
