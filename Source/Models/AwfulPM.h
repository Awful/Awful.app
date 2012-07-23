#import "_AwfulPM.h"
@class TFHppleElement;

@interface AwfulPM : _AwfulPM {}
+(NSMutableArray *)parsePMsWithData:(NSData*)data;
+(NSString*) messageIDFromLinkElement:(TFHppleElement*)a;
@end
