//  AwfulSelfHostingAttachmentInterpolator.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSelfHostingAttachmentInterpolator.h"
#import "AwfulImageURLProtocol.h"
#import "AwfulTextAttachment.h"
#import "ComposeTextView.h"

@implementation AwfulSelfHostingAttachmentInterpolator
{
    NSMutableArray *_URLs;
}

- (void)dealloc
{
    for (NSURL *URL in _URLs) {
        [AwfulImageURLProtocol stopServingImageAtURL:URL];
    }
}

- (NSString *)interpolateImagesInString:(NSAttributedString *)string
{
    _URLs = [NSMutableArray new];
    NSString *basePath = [[NSUUID UUID] UUIDString];
    NSMutableAttributedString *mutableString = [string mutableCopy];
    
    // I'm not sure how to modify the string within calls to -[NSMutableAttributedString enumerateAttribute:...] when the range has length one, unless we go in reverse. I'm not even sure it's a bug.
    [string enumerateAttribute:NSAttachmentAttributeName
                       inRange:NSMakeRange(0, string.length)
                       options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired | NSAttributedStringEnumerationReverse
                    usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop)
    {
        if (!attachment) return;
        
        NSString *t = @"";
        CGSize imageSize = attachment.image.size;
        if (imageSize.width > RequiresThumbnailImageSize.width || imageSize.height > RequiresThumbnailImageSize.height) {
            t = @"t";
        }
        
        NSString *path = [basePath stringByAppendingPathComponent:@(_URLs.count).stringValue];
        NSURL *servedImageURL;
        if ([attachment isKindOfClass:[AwfulTextAttachment class]]) {
            AwfulTextAttachment *awfulAttachment = (AwfulTextAttachment *)attachment;
            if (awfulAttachment.assetURL) {
                servedImageURL = [AwfulImageURLProtocol serveAsset:awfulAttachment.assetURL atPath:path];
            } else {
                servedImageURL = [AwfulImageURLProtocol serveImage:awfulAttachment.thumbnailImage atPath:path];
            }
        } else {
            servedImageURL = [AwfulImageURLProtocol serveImage:attachment.image atPath:path];
        }
        [_URLs addObject:servedImageURL];
        
        // SA: The [img] BBcode seemingly only matches if the URL starts with "http[s]://" or it refuses to actually turn it into an <img> element, so we'll prefix it with http:// and then remove that later.
        NSString *replacement = [NSString stringWithFormat:@"[%@img]http://%@[/%@img]", t, servedImageURL.absoluteString, t];
        [mutableString replaceCharactersInRange:range withAttributedString:[[NSAttributedString alloc] initWithString:replacement]];
    }];
    return mutableString.string;
}

@end
