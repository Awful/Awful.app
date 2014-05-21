//  AwfulTextAttachment.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTextAttachment.h"
#import "AwfulComposeTextView.h"
@import AssetsLibrary;
@import ImageIO;

@interface AwfulTextAttachment ()

@property (strong, nonatomic) UIImage *thumbnailImage;

@end

@implementation AwfulTextAttachment

- (UIImage *)image
{
    UIImage *image = super.image;
    if (image) return image;
    NSData *data = self.contents ?: self.fileWrapper.regularFileContents;
    self.image = image = [UIImage imageWithData:data];
    return image;
}

- (void)setImage:(UIImage *)image
{
    [super setImage:image];
    self.thumbnailImage = nil;
}

#pragma mark - Thumbnails

- (UIImage *)thumbnailImage
{
    if (_thumbnailImage) return _thumbnailImage;
    UIImage *image = self.image;
    CGSize thumbnailSize = AppropriateThumbnailSizeForImageSize(image.size);
    if (CGSizeEqualToSize(image.size, thumbnailSize)) {
        return image;
    }
    
    UIImage *thumbnail;
    if (self.assetURL) {
        thumbnail = ThumbnailImageForAssetWithURL(self.assetURL, thumbnailSize);
    }
    
    if (!thumbnail) {
        thumbnail = ThumbnailImageForImage(image, thumbnailSize);
    }
    
    self.thumbnailImage = thumbnail;
    return _thumbnailImage;
}

static CGSize AppropriateThumbnailSizeForImageSize(CGSize imageSize)
{
    CGFloat widthRatio = imageSize.width / RequiresThumbnailImageSize.width;
    CGFloat heightRatio = imageSize.height / RequiresThumbnailImageSize.height;
    CGFloat screenRatio = imageSize.width / (CGRectGetWidth([UIScreen mainScreen].bounds) - 8);
    CGFloat ratio = MAX(widthRatio, MAX(heightRatio, screenRatio));
    if (ratio > 1) {
        return CGSizeMake(imageSize.width / ratio, imageSize.height / ratio);
    } else {
        return imageSize;
    }
}

static UIImage * ThumbnailImageForAssetWithURL(NSURL *assetURL, CGSize thumbnailSize)
{
    __block UIImage *thumbnail;
    dispatch_semaphore_t flag = dispatch_semaphore_create(0);
    ALAssetsLibrary *library = [ALAssetsLibrary new];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
            thumbnail = [UIImage imageWithCGImage:asset.aspectRatioThumbnail];
            dispatch_semaphore_signal(flag);
        } failureBlock:^(NSError *error) {
            // nop
            dispatch_semaphore_signal(flag);
        }];
    });
    dispatch_semaphore_wait(flag, DISPATCH_TIME_FOREVER);
    return thumbnail;
}

static UIImage * ThumbnailImageForImage(UIImage *image, CGSize thumbnailSize)
{
    UIGraphicsBeginImageContextWithOptions(thumbnailSize, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, thumbnailSize.width, thumbnailSize.height)];
    UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return thumbnail;
}

#pragma mark - NSTextAttachmentContainer

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex
{
    CGSize thumbnailSize = AppropriateThumbnailSizeForImageSize(self.thumbnailImage.size);
    return CGRectMake(0, 0, thumbnailSize.width, thumbnailSize.height);
}

- (UIImage *)imageForBounds:(CGRect)imageBounds textContainer:(NSTextContainer *)textContainer characterIndex:(NSUInteger)charIndex
{
    return self.thumbnailImage;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _assetURL = [coder decodeObjectForKey:AssetURLKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:self.assetURL forKey:AssetURLKey];
}

static NSString * const AssetURLKey = @"AwfulAssetURL";

@end
