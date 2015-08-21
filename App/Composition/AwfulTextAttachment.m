//  AwfulTextAttachment.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTextAttachment.h"
#import "AwfulFrameworkCategories.h"
#import "ComposeTextView.h"
@import ImageIO;

@interface AwfulTextAttachment ()

@property (strong, nonatomic) UIImage *thumbnailImage;

@end

@implementation AwfulTextAttachment

- (instancetype)initWithImage:(UIImage *)image assetURL:(NSURL *)assetURL
{
    if ((self = [super initWithData:nil ofType:nil])) {
        self.image = image;
        _assetURL = assetURL;
    }
    return self;
}

- (instancetype)initWithData:(NSData *)contentData ofType:(NSString *)UTI
{
    NSAssert(nil, @"Use -initWithImage:assertURL:");
    return [self initWithImage:nil assetURL:nil];
}

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
    
    // Try to get a thumbnail from the assets library. It's super fast.
    UIImage *thumbnail;
    if (self.assetURL) {
        ALAssetsLibrary *library = [ALAssetsLibrary new];
        NSError *error;
        ALAsset *asset = [library awful_assetForURL:self.assetURL error:&error];
        if (asset) {
            thumbnail = [UIImage imageWithCGImage:asset.aspectRatioThumbnail];
        } else {
            NSLog(@"%s could not find asset, using image instead: %@", __PRETTY_FUNCTION__, error);
        }
    }
    
    // If the assets library doesn't come through, resize the image we do have. May be slow and memory intensive.
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

// -initWithCoder: doesn't seem to be recognized as a designated initializer for NSTextAttachment, so we quash the warnings.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _assetURL = [coder decodeObjectForKey:AssetURLKey];
    }
    return self;
}

#pragma clang diagnostic pop

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:self.assetURL forKey:AssetURLKey];
}

static NSString * const AssetURLKey = @"AwfulAssetURL";

static const CGSize RequiresThumbnailImageSize = {800, 600};

@end

BOOL ImageSizeRequiresThumbnailing(CGSize imageSize) {
    return imageSize.width > RequiresThumbnailImageSize.width || imageSize.height > RequiresThumbnailImageSize.height;
}
