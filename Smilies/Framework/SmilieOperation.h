//  SmilieOperation.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
@class SmilieDataStore;

/**
 Deletes smilies in the app container smilie store that have subsequently appeared in the bundled smilie store.
 */
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

/**
 Downloads the smilie list from the SA Forums and compares it to the smilies already known about. New smilies will be inserted, but they will have no image data until a `SmilieDownloadMissingImageDataOperation` runs on the data store.
 
 Does nothing if a SmilieScrapeAndInsertNewSmiliesOperation has successfully completed on the data store in the last day or so.
 */
@interface SmilieScrapeAndInsertNewSmiliesOperation : NSOperation

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore smilieListHTML:(NSString *)HTML;

@property (readonly, strong, nonatomic) SmilieDataStore *dataStore;
@property (readonly, strong, nonatomic) NSString *smilieListHTML;

@end
