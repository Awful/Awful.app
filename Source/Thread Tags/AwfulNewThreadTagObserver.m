//  AwfulNewThreadTagObserver.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewThreadTagObserver.h"
#import "AwfulThreadTagLoader.h"

@interface AwfulNewThreadTagObserver ()

@property (copy, nonatomic) void (^downloadedBlock)(UIImage *image);

@end

@implementation AwfulNewThreadTagObserver

- (void)dealloc
{
    [self stopObserving];
}

- (instancetype)initWithImageName:(NSString *)imageName downloadedBlock:(void (^)(UIImage *image))downloadedBlock
{
    if ((self = [super init])) {
        _imageName = [imageName stringByDeletingPathExtension];
        _downloadedBlock = [downloadedBlock copy];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(newThreadTagDidDownload:)
                                                     name:AwfulThreadTagLoaderNewImageAvailableNotification
                                                   object:nil];
    }
    return self;
}

- (void)newThreadTagDidDownload:(NSNotification *)notification
{
    NSString *newImageName = notification.userInfo[AwfulThreadTagLoaderNewImageNameKey];
    if ([newImageName isEqualToString:self.imageName]) {
        [self stopObserving];
        
        if (self.downloadedBlock) {
            AwfulThreadTagLoader *loader = notification.object;
            UIImage *image = [loader imageNamed:newImageName];
            self.downloadedBlock(image);
        }
    }
}

- (void)stopObserving
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AwfulThreadTagLoaderNewImageAvailableNotification object:nil];
}

@end
