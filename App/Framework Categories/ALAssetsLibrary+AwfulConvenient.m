//  ALAssetsLibrary+AwfulConvenient.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ALAssetsLibrary+AwfulConvenient.h"

@implementation ALAssetsLibrary (AwfulConvenient)

- (ALAsset *)awful_assetForURL:(NSURL *)URL error:(out NSError **)error
{
    __block ALAsset *asset;
    dispatch_semaphore_t flag = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self assetForURL:URL resultBlock:^(ALAsset *blockAsset) {
            if (blockAsset) {
                asset = blockAsset;
                dispatch_semaphore_signal(flag);
            } else {
                // iOS 8 workaround for photo stream from http://stackoverflow.com/a/26526199/1063051
                [self enumerateGroupsWithTypes:ALAssetsGroupPhotoStream usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                    [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                        if ([result.defaultRepresentation.url isEqual:URL]) {
                            asset = result;
                            *stop = YES;
                        }
                    }];
                    if (asset) {
                        *stop = YES;
                    }
                    if (!group) {
                        dispatch_semaphore_signal(flag);
                    }
                } failureBlock:^(NSError *blockError) {
                    *error = blockError;
                    dispatch_semaphore_signal(flag);
                }];
            }
        } failureBlock:^(NSError *blockError) {
            if (error) *error = blockError;
            dispatch_semaphore_signal(flag);
        }];
    });
    dispatch_semaphore_wait(flag, DISPATCH_TIME_FOREVER);
    return asset;
}

@end
