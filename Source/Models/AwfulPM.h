#import "_AwfulPM.h"
@class TFHppleElement;

@interface AwfulPM : _AwfulPM {}
+(NSMutableArray *)parsePMListWithData:(NSData*)data;
+(NSString*) messageIDFromLinkElement:(TFHppleElement*)a;


+(NSMutableArray *)parsePM:(AwfulPM*)message withData:(NSData*)data;
@end
