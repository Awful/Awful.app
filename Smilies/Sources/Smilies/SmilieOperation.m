//  SmilieOperation.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieOperation.h"
@import HTMLReader;
@import ImageIO;
#import "Smilie.h"
#import "SmilieAppContainer.h"
#import "SmilieDataStore.h"

@implementation SmilieCleanUpDuplicateDataOperation

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore
{
    if ((self = [super init])) {
        _dataStore = dataStore;
    }
    return self;
}

- (void)main
{
    if (!SmilieKeyboardHasFullAccess()) {
        NSLog(@"%s bailing; keyboard does not have full access", __PRETTY_FUNCTION__);
        return;
    }
    
    NSPersistentStoreCoordinator *storeCoordinator = self.dataStore.managedObjectContext.persistentStoreCoordinator;
    NSDictionary *bundledMetadata = [storeCoordinator metadataForPersistentStore:self.dataStore.bundledSmilieStore];
    NSDictionary *appContainerMetadata = [storeCoordinator metadataForPersistentStore:self.dataStore.appContainerSmilieStore];
    
    if ([bundledMetadata[SmilieMetadataVersionKey] isEqual:appContainerMetadata[SmilieMetadataVersionKey]]) return;

    NSArray *downloadedSmilieTexts;
    {{
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
        fetchRequest.resultType = NSDictionaryResultType;
        fetchRequest.propertiesToFetch = @[@"text"];
        if (!self.dataStore.appContainerSmilieStore) {
            NSLog(@"%s no container smilie store, so nothing to do", __PRETTY_FUNCTION__);
            return;
        }
        fetchRequest.affectedStores = @[self.dataStore.appContainerSmilieStore];
        NSError *error;
        NSArray *results = [self.dataStore.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (!results) {
            NSLog(@"%s error fetching app container store's smilies: %@", __PRETTY_FUNCTION__, error);
            return;
        }
        downloadedSmilieTexts = [results valueForKey:@"text"];
    }}
    
    NSArray *duplicatedSmilieTexts;
    if (downloadedSmilieTexts.count > 0) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
        fetchRequest.resultType = NSDictionaryResultType;
        fetchRequest.propertiesToFetch = @[@"text"];
        fetchRequest.affectedStores = @[self.dataStore.bundledSmilieStore];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"text IN %@", downloadedSmilieTexts];
        NSError *error;
        NSArray *results = [self.dataStore.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (!results) {
            NSLog(@"%s error fetching downloaded smilies in the bundled store: %@", __PRETTY_FUNCTION__, error);
            return;
        }
        duplicatedSmilieTexts = [results valueForKey:@"text"];
    }
    
    if (duplicatedSmilieTexts.count > 0) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"text IN %@", duplicatedSmilieTexts];
        fetchRequest.affectedStores = @[self.dataStore.appContainerSmilieStore];
        NSError *error;
        NSArray *results = [self.dataStore.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (!results) {
            NSLog(@"%s error fetching duplicated smilies in the app container store: %@", __PRETTY_FUNCTION__, error);
            return;
        }
        for (Smilie *smilie in results) {
            [smilie.managedObjectContext deleteObject:smilie];
        }
        if (![self.dataStore.managedObjectContext save:&error]) {
            NSLog(@"%s error saving: %@", __PRETTY_FUNCTION__, error);
            return;
        }
    }
    
    // Cleanup was a success.
    NSMutableDictionary *newMetadata = [appContainerMetadata mutableCopy];
    newMetadata[SmilieMetadataVersionKey] = bundledMetadata[SmilieMetadataVersionKey] ?: @0;
    [storeCoordinator setMetadata:newMetadata forPersistentStore:self.dataStore.appContainerSmilieStore];
}

@end

@interface SmilieDownloadMissingImageDataOperation ()

@property (getter=isExecuting, nonatomic) BOOL executing;
@property (getter=isFinished, nonatomic) BOOL finished;

@property (strong, nonatomic) NSManagedObjectContext *context;
@property (strong, nonatomic) NSURLSession *URLSession;
@property (strong, nonatomic) NSMutableArray *tasks;

@end

@implementation SmilieDownloadMissingImageDataOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore URLSession:(NSURLSession *)URLSession
{
    if ((self = [super init])) {
        _dataStore = dataStore;
        _URLSession = URLSession;
    }
    return self;
}

- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isAsynchronous
{
    return YES;
}

- (NSURLSession *)URLSession
{
    if (!_URLSession) {
        _URLSession = [NSURLSession sharedSession];
    }
    return _URLSession;
}

- (NSManagedObjectContext *)context
{
    if (!_context) {
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _context.parentContext = self.dataStore.managedObjectContext;
    }
    return _context;
}

- (NSMutableArray *)tasks
{
    if (!_tasks) {
        _tasks = [NSMutableArray new];
    }
    return _tasks;
}

- (void)start
{
    if (self.cancelled) {
        return;
    }
    
    if (!SmilieKeyboardHasFullAccess()) {
        NSLog(@"%s bailing; keyboard does not have full access", __PRETTY_FUNCTION__);
        return;
    }
    
    self.executing = YES;
    
    [self.context performBlock:^{
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"imageData = nil AND imageURL != nil"];
        NSError *error;
        NSArray *results = [self.context executeFetchRequest:fetchRequest error:&error];
        if (!results) {
            NSLog(@"%s error fetching: %@", __PRETTY_FUNCTION__, error);
        }
        
        [self downloadImageDataForSmilies:results];
    }];
}

- (void)downloadImageDataForSmilies:(NSArray *)smilies
{
    if (self.cancelled) {
        return;
    }
    
    if (smilies.count == 0) {
        [self finish];
        return;
    }
    
    for (Smilie *smilie in smilies) {
        NSURL *URL = [NSURL URLWithString:smilie.imageURL];
        __block NSURLSessionDataTask *task = [self.URLSession dataTaskWithURL:URL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"%s image download error: %@", __PRETTY_FUNCTION__, error);
                [self taskDidComplete:task];
                return;
            }
            
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
                NSInteger statusCode = HTTPResponse.statusCode;
                if (statusCode < 200 || statusCode >= 300) {
                    NSLog(@"%s image download bad response: %@", __PRETTY_FUNCTION__, HTTPResponse);
                    [self taskDidComplete:task];
                    return;
                }
            }
            
            [smilie.managedObjectContext performBlock:^{
                if (self.cancelled) {
                    return;
                }
                
                smilie.imageData = data;
                UpdateSmilieImageDataDerivedAttributes(smilie);
                
                // The session's delegateQueue will be a serial queue, so let's (ab)use it to thread-safe calls to -taskDidComplete:.
                [self.URLSession.delegateQueue addOperationWithBlock:^{
                    [self taskDidComplete:task];
                }];
            }];
        }];
        [self.tasks addObject:task];
        [task resume];
    }
}

void UpdateSmilieImageDataDerivedAttributes(Smilie *smilie)
{
    CGFloat width = 0, height = 0;
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)smilie.imageData, nil);
    smilie.imageUTI = (NSString *)CGImageSourceGetType(imageSource);
    
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil);
    CFNumberRef boxedWidth = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
    if (boxedWidth) CFNumberGetValue(boxedWidth, kCFNumberCGFloatType, &width);
    CFNumberRef boxedHeight = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
    if (boxedHeight) CFNumberGetValue(boxedHeight, kCFNumberCGFloatType, &height);
    NSInteger orientation = 0;
    CFNumberRef boxedOrientation = CFDictionaryGetValue(imageProperties, kCGImagePropertyOrientation);
    if (boxedOrientation) CFNumberGetValue(boxedOrientation, kCFNumberNSIntegerType, &orientation);
    if (orientation < 5) {
        smilie.imageSize = CGSizeMake(width, height);
    } else {
        smilie.imageSize = CGSizeMake(height, width);
    }
    CFRelease(imageProperties);
    
    CFRelease(imageSource);
}

- (void)taskDidComplete:(NSURLSessionDataTask *)task
{
    if (self.cancelled) {
        return;
    }
    
    [self.tasks removeObject:task];
    
    if (self.tasks.count == 0) {
        [self.context performBlock:^{
            if (self.context.hasChanges) {
                NSError *error;
                if (![self.context save:&error]) {
                    NSLog(@"%s error saving: %@", __PRETTY_FUNCTION__, error);
                } else {
                    if (![self.dataStore.managedObjectContext save:&error]) {
                        NSLog(@"%s error saving parent: %@", __PRETTY_FUNCTION__, error);
                    }
                }
            }
            [self finish];
        }];
    }
}

- (void)finish
{
    self.executing = NO;
    self.finished = YES;
}

- (void)cancel
{
    [self.tasks makeObjectsPerformSelector:@selector(cancel)];
    [self finish];
    [super cancel];
}

@end

@interface SmilieScrapeAndInsertNewSmiliesOperation ()

@property (strong, nonatomic) NSManagedObjectContext *context;

@end

@implementation SmilieScrapeAndInsertNewSmiliesOperation

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore smilieListHTML:(NSString *)HTML
{
    if ((self = [super init])) {
        _dataStore = dataStore;
        _smilieListHTML = HTML;
    }
    return self;
}

- (NSManagedObjectContext *)context
{
    if (!_context) {
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _context.parentContext = self.dataStore.managedObjectContext;
    }
    return _context;
}

- (void)main
{
    if (!SmilieKeyboardHasFullAccess()) {
        NSLog(@"%s bailing; keyboard does not have full access", __PRETTY_FUNCTION__);
        return;
    }
    
    NSDictionary *metadata = [self.dataStore.storeCoordinator metadataForPersistentStore:self.dataStore.appContainerSmilieStore];
    NSDate *lastSuccessfulScrape = metadata[SmilieLastSuccessfulScrapeDateKey];
    if (lastSuccessfulScrape && -[lastSuccessfulScrape timeIntervalSinceNow] > 60 * 60 * 20) return;
    
    HTMLDocument *document = [HTMLDocument documentWithString:self.smilieListHTML];
    HTMLElement *container = [document firstNodeMatchingSelector:@".smilie_list"];
    NSArray *headers = [container nodesMatchingSelector:@"h3"];
    NSArray *lists = [container nodesMatchingSelector:@".smilie_group"];
    if (headers.count != lists.count) {
        NSLog(@"%s expected equal numbers of section headers (%@) and sections (%@)", __PRETTY_FUNCTION__, @(headers.count), @(lists.count));
        return;
    }
    
    NSMutableArray *scrapedTexts = [NSMutableArray new];
    {{
        for (HTMLElement *section in lists) {
            NSArray *texts = [[section nodesMatchingSelector:@"li .text"] valueForKey:@"textContent"];
            [scrapedTexts addObjectsFromArray:texts];
        }
        [scrapedTexts sortUsingSelector:@selector(compare:)];
    }}
    
    if (self.cancelled) return;
    
    NSArray *knownTexts;
    {{
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
        fetchRequest.resultType = NSDictionaryResultType;
        fetchRequest.propertiesToFetch = @[@"text"];
        __block NSError *error;
        __block NSArray *results;
        [self.context performBlockAndWait:^{
            results = [self.context executeFetchRequest:fetchRequest error:&error];
        }];
        if (!results) {
            NSLog(@"%s error fetching known smilies: %@", __PRETTY_FUNCTION__, error);
            return;
        }
        knownTexts = [[results valueForKey:@"text"] sortedArrayUsingSelector:@selector(compare:)];
    }}
    
    if (self.cancelled) return;
    
    NSMutableArray *newTexts = [NSMutableArray new];
    {{
        NSUInteger scrapedIndex = 0, knownIndex = 0;
        for (; scrapedIndex < scrapedTexts.count && knownIndex < knownTexts.count; scrapedIndex++) {
            NSString *scraped = scrapedTexts[scrapedIndex];
            NSString *known = knownTexts[knownIndex];
            if ([scraped isEqualToString:known]) {
                knownIndex++;
            } else {
                [newTexts addObject:scraped];
            }
        }
        [newTexts addObjectsFromArray:[scrapedTexts subarrayWithRange:NSMakeRange(scrapedIndex, scrapedTexts.count - scrapedIndex)]];
    }}
    
    if (newTexts.count == 0 || self.cancelled) return;
    
    [self.context performBlockAndWait:^{
        [headers enumerateObjectsUsingBlock:^(HTMLElement *header, NSUInteger i, BOOL *stop) {
            if (self.cancelled) return;
            
            HTMLElement *section = lists[i];
            for (HTMLElement *item in [section nodesMatchingSelector:@"li"]) {
                NSString *text = [item firstNodeMatchingSelector:@".text"].textContent;
                if (![newTexts containsObject:text]) continue;
                
                Smilie *smilie = [Smilie newInManagedObjectContext:self.context];
                smilie.text = text;
                HTMLElement *img = [item firstNodeMatchingSelector:@"img"];
                smilie.imageURL = img[@"src"];
                smilie.section = header.textContent;
                smilie.summary = img[@"title"];
            }
        }];
        
        if (self.cancelled) return;
        
        NSMutableDictionary *newMetadata = [metadata mutableCopy];
        newMetadata[SmilieLastSuccessfulScrapeDateKey] = [NSDate date];
        [self.dataStore.storeCoordinator setMetadata:newMetadata forPersistentStore:self.dataStore.appContainerSmilieStore];
        
        NSError *error;
        if (![self.context save:&error]) {
            NSLog(@"%s error saving: %@", __PRETTY_FUNCTION__, error);
        } else {
            if (![self.dataStore.managedObjectContext save:&error]) {
                NSLog(@"%s error saving parent: %@", __PRETTY_FUNCTION__, error);
            }
        }
    }];
}

@end
