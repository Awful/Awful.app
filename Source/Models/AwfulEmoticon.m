#import "AwfulEmoticon.h"


@interface AwfulEmoticon ()

// Private interface goes here.

@end


@implementation AwfulEmoticon

-(CGSize) size {
    if (self.widthValue > 0 && self.heightValue > 0)
        return CGSizeMake(self.widthValue, self.heightValue);
    return CGSizeZero;
}
@end
