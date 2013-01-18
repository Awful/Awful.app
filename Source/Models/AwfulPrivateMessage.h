#import "_AwfulPrivateMessage.h"

@interface AwfulPrivateMessage : _AwfulPrivateMessage {}
- (NSString *)firstIconName;

+ (NSArray *)privateMessagesCreatedOrUpdatedWithParsedInfo:(NSArray *)messageInfos;
@end
