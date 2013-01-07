#import "AwfulPrivateMessage.h"

@implementation AwfulPrivateMessage

- (NSString *)firstIconName
{
    NSString *basename = [[self.threadIconImageURL lastPathComponent]
                          stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}
@end
