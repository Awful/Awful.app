//  Smilie.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Smilie.h"
#import "SmilieMetadata.h"
@import UIKit;

@interface Smilie ()

@property (copy, nonatomic) NSArray *fetchedMetadata;
@property (copy, nonatomic) NSString *imageSizeString;

@end

@implementation Smilie
{
    CGSize _imageSize;
}

@dynamic imageData;
@dynamic imageURL;
@dynamic section;
@dynamic text;

@dynamic fetchedMetadata;
@dynamic imageSizeString;

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    
    NSString *sizeString = self.imageSizeString;
    if (sizeString.length > 0) {
        _imageSize = CGSizeFromString(sizeString);
    }
}

- (CGSize)imageSize
{
    [self willAccessValueForKey:@"imageSize"];
    CGSize imageSize = _imageSize;
    [self didAccessValueForKey:@"imageSize"];
    return imageSize;
}

- (void)setImageSize:(CGSize)imageSize
{
    [self willChangeValueForKey:@"imageSize"];
    _imageSize = imageSize;
    [self didChangeValueForKey:@"imageSize"];
    self.imageSizeString = CGSizeEqualToSize(imageSize, CGSizeZero) ? nil : NSStringFromCGSize(imageSize);
}

- (SmilieMetadata *)metadata
{
    if (self.fetchedMetadata.count > 0) {
        return self.fetchedMetadata[0];
    } else {
        SmilieMetadata *metadata = [SmilieMetadata newInManagedObjectContext:self.managedObjectContext];
        metadata.smilieText = self.text;
        
        // Forget cached empty fetchedMetadata array so we're not making duplicate metadata.
        [self.managedObjectContext refreshObject:self mergeChanges:YES];
        
        return metadata;
    }
}

@end
