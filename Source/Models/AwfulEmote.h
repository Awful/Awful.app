#import "_AwfulEmote.h"

@interface AwfulEmote : _AwfulEmote {}
+(NSArray*)parseEmoticonsWithData : (NSData *)data;
+(void) cacheEmoticon:(AwfulEmote*)emote data:(NSData*)data ;
@property (readonly) BOOL isCached;
@end
