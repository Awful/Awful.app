#import "_AwfulThreadTag.h"

@class TFHppleElement;

@interface AwfulThreadTag : _AwfulThreadTag {}

+(NSArray*)parseThreadTagsForForum:(AwfulForum*)forum withData : (NSData *)data;
+(void) cacheThreadTag:(AwfulThreadTag*)emote data:(NSData*)data ;

+(void) updateTags:(NSArray*)tags forForum:(AwfulForum*)forum;
+(NSNumber*) tagIDFromLinkElement:(TFHppleElement*)a;
@property (nonatomic,readonly) UIImage* image;
@end
