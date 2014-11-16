//  AwfulNewThreadTagObserver.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 * An AwfulNewThreadTagObserver waits for a particular new thread tag to be downloaded.
 */
@interface AwfulNewThreadTagObserver : NSObject

- (instancetype)initWithImageName:(NSString *)imageName downloadedBlock:(void (^)(UIImage *image))downloadedBlock NS_DESIGNATED_INITIALIZER;

/**
 * The image being sought after.
 */
@property (readonly, copy, nonatomic) NSString *imageName;

/**
 * A block to call after the sought-after image is downloaded, which returns nothing and takes the image as its sole parameter.
 */
@property (readonly, copy, nonatomic) void (^downloadedBlock)(UIImage *image);

@end
