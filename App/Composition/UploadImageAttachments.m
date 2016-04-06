//  UploadImageAttachments.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UploadImageAttachments.h"
#import <ImgurAnonymousAPIClient/ImgurAnonymousAPIClient.h>
@import Photos;

#import "Awful-Swift.h"

@interface ImageTag : NSObject

@property (nonatomic) TextAttachment *attachment;
@property (nonatomic) NSRange range;
@property (nonatomic) CGSize imageSize;
@property (nonatomic) NSURL *URL;

@property (readonly, nonatomic) NSString *BBcode;

@end

@implementation ImageTag

- (NSString *)BBcode
{
    CGSize maxSize = [TextAttachment requiresThumbnailImageSize];
    BOOL requiresThumbnailing = self.imageSize.width > maxSize.width || self.imageSize.height > maxSize.height;
    NSString *t = requiresThumbnailing ? @"t" : @"";
    return [NSString stringWithFormat:@"[%@img]%@[/%@img]", t, self.URL.absoluteString, t];
}

@end

static NSArray * AttachmentsInString(NSAttributedString *string)
{
    NSMutableArray *attachments = [NSMutableArray new];
    [string enumerateAttribute:NSAttachmentAttributeName
                       inRange:NSMakeRange(0, string.length)
                       options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                    usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop)
     {
         if ([attachment isKindOfClass:[TextAttachment class]]) {
             ImageTag *tag = [ImageTag new];
             tag.attachment = (TextAttachment *)attachment;
             tag.range = range;
             [attachments addObject:tag];
         }
     }];
    return attachments;
}

static NSArray * AssetURLsOrImagesForTags(NSArray *tags)
{
    NSMutableArray *images = [NSMutableArray new];
    for (ImageTag *tag in tags) {
        if (tag.attachment.assetURL) {
            // Images in the assets library can be uploaded directly from the library. Just need to grab the size of the image for timg purposes.
            PHAsset *asset = [PHAsset fetchAssetsWithALAssetURLs:@[tag.attachment.assetURL] options:nil].firstObject;
            tag.imageSize = CGSizeMake(asset.pixelWidth, asset.pixelHeight);
            [images addObject:tag.attachment.assetURL];
        } else {
            tag.imageSize = tag.attachment.image.size;
            [images addObject:tag.attachment.image];
        }
    }
    return images;
}

static NSProgress * UploadImages(NSArray *images, void (^completion)(NSArray *URLs, NSError *error)) {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:images.count];
    dispatch_group_t group = dispatch_group_create();
    NSPointerArray *URLs = [NSPointerArray strongObjectsPointerArray];
    URLs.count = images.count;
    for (id image in images) {
        dispatch_group_enter(group);
        [progress becomeCurrentWithPendingUnitCount:1];
        void (^uploadComplete)() = ^(NSURL *imgurURL, NSError *error) {
            if (error) {
                if (!progress.cancelled) {
                    [progress cancel];
                    if (completion) completion(nil, error);
                }
            } else {
                [URLs replacePointerAtIndex:[images indexOfObject:image] withPointer:(__bridge void *)imgurURL];
            }
            dispatch_group_leave(group);
        };
        if ([image isKindOfClass:[NSURL class]]) {
            [[ImgurAnonymousAPIClient sharedClient] uploadAssetWithURL:image filename:@"image.png" completionHandler:uploadComplete];
        } else {
            [[ImgurAnonymousAPIClient sharedClient] uploadImage:image withFilename:@"image.png" completionHandler:uploadComplete];
        }
        [progress resignCurrent];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (progress.cancelled) {
            if (completion) completion(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]);
        } else {
            if (completion) completion(URLs.allObjects, nil);
        }
    });
    return progress;
}

static NSString * ReplaceAttachmentsWithTags(NSAttributedString *richText, NSArray *tags)
{
    NSMutableString *string = [NSMutableString stringWithString:richText.string];
    for (ImageTag *tag in tags.reverseObjectEnumerator) {
         [string replaceCharactersInRange:tag.range withString:tag.BBcode];
    }
    return string;
}

NSProgress * UploadImageAttachments(NSAttributedString *richText, void (^completion)(NSString *plainText, NSError *error))
{
    richText = [richText copy];
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSArray *tags = AttachmentsInString(richText);
        if (tags.count == 0) {
            --progress.totalUnitCount;
            
            return dispatch_async(dispatch_get_main_queue(), ^{
                completion(richText.string, nil);
            });
        }
        
        if (progress.cancelled) {
            return dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]);
            });
        }
        
        NSArray *assetsAndImages = AssetURLsOrImagesForTags(tags);
        [progress becomeCurrentWithPendingUnitCount:1];
        UploadImages(assetsAndImages, ^(NSArray *URLs, NSError *error) {
            if (error) {
                return completion(nil, error);
            }
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                [URLs enumerateObjectsUsingBlock:^(NSURL *URL, NSUInteger i, BOOL *stop) {
                    ImageTag *tag = tags[i];
                    tag.URL = URL;
                }];
                NSString *plainText = ReplaceAttachmentsWithTags(richText, tags);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(plainText, nil);
                });
            });
        });
        [progress resignCurrent];
    });
    return progress;
}
