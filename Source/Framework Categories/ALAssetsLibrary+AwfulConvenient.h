//  ALAssetsLibrary+AwfulConvenient.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import AssetsLibrary;

@interface ALAssetsLibrary (AwfulConvenient)

/**
 * A synchronous version of -assetForURL:resultBlock:failureBlock:
 */
- (ALAsset *)awful_assetForURL:(NSURL *)URL error:(out NSError **)error;

@end
