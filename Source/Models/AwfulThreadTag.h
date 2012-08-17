#import "_AwfulThreadTag.h"

@class TFHppleElement;

static NSDictionary* tags;

@interface AwfulThreadTag : _AwfulThreadTag

+(NSArray*)parseThreadTagsForForum:(AwfulForum*)forum withData : (NSData *)data;
+(void) cacheThreadTag:(AwfulThreadTag*)emote data:(NSData*)data ;

+(void) updateTags:(NSArray*)tags forForum:(AwfulForum*)forum;
+(NSNumber*) tagIDFromLinkElement:(TFHppleElement*)a;
+(AwfulThreadTag*) tagFromElement:(TFHppleElement*)img;

+(void) getTagsForThreads:(NSArray*)threads;
-(void) displayInImageView:(UIImageView*)imageView;
@property (nonatomic,readonly) UIImage* image;
@end
