//  AwfulTextAttachment.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTextAttachment.h"
#import "AwfulComposeTextView.h"

@implementation AwfulTextAttachment

- (UIImage *)image
{
    UIImage *image = super.image;
    if (image) return image;
    NSData *data = self.contents ?: self.fileWrapper.regularFileContents;
    self.image = image = [UIImage imageWithData:data];
    return image;
}

#pragma mark - NSTextAttachmentContainer

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex
{
    CGSize imageSize = self.image.size;
    CGFloat widthRatio = imageSize.width / RequiresThumbnailImageSize.width;
    CGFloat heightRatio = imageSize.height / RequiresThumbnailImageSize.height;
    CGFloat screenRatio = imageSize.width / (CGRectGetWidth([UIScreen mainScreen].bounds) - 8);
    if (widthRatio > 1 || heightRatio > 1 || screenRatio > 1) {
        CGFloat ratio = MAX(widthRatio, MAX(heightRatio, screenRatio));
        return CGRectIntegral(CGRectMake(0, 0, imageSize.width / ratio, imageSize.height / ratio));
    } else {
        return (CGRect){ .size = imageSize };
    }
}

@end
