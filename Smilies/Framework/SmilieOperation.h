//  SmilieOperation.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
@class SmilieDataStore;

@interface SmilieCleanUpDuplicateDataOperation : NSOperation

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore;

@property (readonly, strong, nonatomic) SmilieDataStore *dataStore;

@end

@interface SmilieDownloadMissingImageDataOperation : NSOperation

/**
 * @param URLSession The URL session to use for downloading; if nil, the shared NSURLSession is used.
 */
- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore URLSession:(NSURLSession *)URLSession;

@property (readonly, strong, nonatomic) SmilieDataStore *dataStore;
@property (readonly, strong, nonatomic) NSURLSession *URLSession;

@end

@interface SmilieScrapeAndInsertNewSmiliesOperation : NSOperation

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore smilieListHTML:(NSString *)HTML;

@property (readonly, strong, nonatomic) SmilieDataStore *dataStore;
@property (readonly, strong, nonatomic) NSString *smilieListHTML;

@end
