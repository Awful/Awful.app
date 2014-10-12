//  SmilieKeyboard.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieKeyboard.h"
#import "SmilieDataStore.h"
#import "SmilieFavoriteToggler.h"
#import "SmilieFetchedDataSource.h"
#import "SmilieKeyboardView.h"
#import "SmilieOperation.h"

@interface SmilieKeyboard () <SmilieKeyboardViewDelegate>

@property (strong, nonatomic) SmilieKeyboardView *view;
@property (strong, nonatomic) SmilieFetchedDataSource *dataSource;

@property (strong, nonatomic) NSOperationQueue *queue;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSURLSessionDataTask *task;

@end

@implementation SmilieKeyboard

- (void)dealloc
{
    [_task cancel];
    [_timer invalidate];
    [_queue cancelAllOperations];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _dataStore = [SmilieDataStore new];
        _view = [SmilieKeyboardView newFromNib];
        _view.delegate = self;
        _queue = [NSOperationQueue new];
        
        __weak __typeof__(self) weakSelf = self;
        NSOperation *cleanUpOperation = [[SmilieCleanUpDuplicateDataOperation alloc] initWithDataStore:_dataStore];
        cleanUpOperation.completionBlock = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf cleanUpDidFinish];
            });
        };
        [_queue addOperation:cleanUpOperation];
    }
    return self;
}

- (void)cleanUpDidFinish
{
    self.dataSource = [[SmilieFetchedDataSource alloc] initWithDataStore:self.dataStore];
    self.view.dataSource = self.dataSource;
    [self.view reloadData];
    
    // Wait a few seconds after launch before scraping. There's no point kicking off some network requests when someone's quickly tapping through their keyboards.
    self.timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(startScrapingTasks:) userInfo:nil repeats:NO];
}

- (void)startScrapingTasks:(NSTimer *)timer
{
    self.timer = nil;
    
    __weak __typeof__(self) weakSelf = self;
    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *URL = [NSURL URLWithString:@"http://forums.somethingawful.com/misc.php?action=showsmilies"];
    self.task = [session dataTaskWithURL:URL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __typeof__(self) self = weakSelf;
        SmilieScrapeAndInsertNewSmiliesOperation *scrapeOperation;
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
        if (error || (HTTPResponse.statusCode < 200 || HTTPResponse.statusCode >= 300)) {
            NSLog(@"%s error fetching smilie list HTML: %@\nheaders: %@", __PRETTY_FUNCTION__, error, HTTPResponse.allHeaderFields);
        } else {
            NSString *HTML = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
            scrapeOperation = [[SmilieScrapeAndInsertNewSmiliesOperation alloc] initWithDataStore:self.dataStore smilieListHTML:HTML];
        }
        
        SmilieDownloadMissingImageDataOperation *downloadOperation = [[SmilieDownloadMissingImageDataOperation alloc] initWithDataStore:self.dataStore URLSession:session];
        if (scrapeOperation) {
            [downloadOperation addDependency:scrapeOperation];
            [self.queue addOperation:scrapeOperation];
        }
        [self.queue addOperation:downloadOperation];
        self.task = nil;
    }];
    [self.task resume];
}

#pragma mark - SmilieKeyboardViewDelegate

- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboardView *)keyboardView
{
    [self.delegate advanceToNextInputModeForSmilieKeyboard:self];
}

- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboardView *)keyboardView
{
    [self.delegate deleteBackwardForSmilieKeyboard:self];
}

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didTapSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    Smilie *smilie = [self.dataSource smilieAtIndexPath:indexPath];
    [self.delegate smilieKeyboard:self didTapSmilie:smilie];
}

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didLongPressSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    Smilie *smilie = [self.dataSource smilieAtIndexPath:indexPath];
    UICollectionViewCell *cell = [self.view.collectionView cellForItemAtIndexPath:indexPath];
    SmilieFavoriteToggler *toggler = [[SmilieFavoriteToggler alloc] initWithSmilie:smilie pointingAtView:cell];
    [self.delegate smilieKeyboard:self presentFavoriteToggler:toggler];
}

@end
