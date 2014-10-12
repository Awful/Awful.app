//  ViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ViewController.h"
@import CoreData;
#import <HTMLReader/HTMLReader.h>
@import ImageIO;
@import Smilies;
#import "SmilieWebArchive.h"

@interface ViewController ()

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSURL *storeURL;
@property (strong, nonatomic) SmilieWebArchive *archive;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *replaceBarButtonItem;
@property (strong, nonatomic) IBOutlet UITextView *textView;

@end

@implementation ViewController

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        NSManagedObjectModel *model = [SmilieDataStore managedObjectModel];
        NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        [[NSFileManager defaultManager] createDirectoryAtURL:[self.storeURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        
        // Keep the data store to a single file. The journal won't help us for a read-only store anyway.
        NSDictionary *options = @{NSSQLitePragmasOption: @{@"journal_mode": @"DELETE"}};
        
        NSError *error;
        if (![storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:@"NoMetadata" URL:self.storeURL options:options error:&error]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"could not start store coordinator" userInfo:nil];
        }
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _managedObjectContext.persistentStoreCoordinator = storeCoordinator;
    }
    return _managedObjectContext;
}

- (NSURL *)storeURL
{
    if (!_storeURL) {
        NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].lastObject;
        _storeURL = [documentsURL URLByAppendingPathComponent:@"Smilies.sqlite"];
    }
    return _storeURL;
}

- (SmilieWebArchive *)archive
{
    if (!_archive) {
        NSURL *URL = [[NSBundle bundleForClass:[ViewController class]] URLForResource:@"showsmilies" withExtension:@"webarchive"];
        _archive = [[SmilieWebArchive alloc] initWithURL:URL];
    }
    return _archive;
}

- (IBAction)didTapExtract:(UIBarButtonItem *)sender
{
    sender.enabled = NO;
    self.replaceBarButtonItem.enabled = NO;
    self.textView.text = @"Extracting…";
    
    [[NSFileManager defaultManager] removeItemAtURL:self.storeURL error:nil];
    
    NSDate *start = [NSDate date];
    [self scrapeSmiliesCompletionHandler:^{
        self.managedObjectContext = nil;
        NSDate *finish = [NSDate date];
        NSMutableString *string = [NSMutableString new];
        [string appendFormat:@"Took %g seconds.", [finish timeIntervalSinceDate:start]];
        [string appendFormat:@"\n\n%@", self.storeURL.path];
        self.textView.text = string;
        sender.enabled = YES;
        self.replaceBarButtonItem.enabled = YES;
    }];
}

- (void)scrapeSmiliesCompletionHandler:(void (^)(void))completionHandler
{
    [self.managedObjectContext performBlock:^{
        HTMLDocument *document = [HTMLDocument documentWithString:self.archive.mainFrameHTML];
        HTMLElement *container = [document firstNodeMatchingSelector:@".smilie_list"];
        NSArray *headers = [container nodesMatchingSelector:@"h3"];
        NSArray *lists = [container nodesMatchingSelector:@".smilie_group"];
        NSAssert(headers.count == lists.count, @"expecting equal numbers of section headers and sections");
        
        void (^save)() = ^{
            NSError *error;
            BOOL ok = [self.managedObjectContext save:&error];
            if (!ok) {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"could not save context" userInfo:nil];
            }
        };
        
        [headers enumerateObjectsUsingBlock:^(HTMLElement *header, NSUInteger i, BOOL *stop) {
            HTMLElement *section = lists[i];
            for (HTMLElement *item in [section nodesMatchingSelector:@"li"]) {
                Smilie *smilie = [Smilie newInManagedObjectContext:self.managedObjectContext];
                smilie.text = [item firstNodeMatchingSelector:@".text"].textContent;
                HTMLElement *img = [item firstNodeMatchingSelector:@"img"];
                smilie.imageURL = img[@"src"];
                smilie.section = header.textContent;
                smilie.summary = img[@"title"];
                
                NSData *imageData = [self.archive dataForSubresourceWithURL:[NSURL URLWithString:smilie.imageURL]];
                smilie.imageData = imageData;
                
                CGFloat width = 0, height = 0;
                CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nil);
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
            
            if (i % 100 == 0) save();
        }];
        
        save();
        
        if (completionHandler) dispatch_async(dispatch_get_main_queue(), completionHandler);
    }];
}

- (IBAction)didTapReplace:(UIBarButtonItem *)sender
{
    sender.enabled = NO;
    
    // This is a terrible idea.
    NSURL *thisFileURL = [NSURL fileURLWithPath:[NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding]];
    NSURL *smiliesFolderURL = [[thisFileURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent];
    NSURL *frameworkURL = [smiliesFolderURL URLByAppendingPathComponent:@"Framework"];
    NSURL *destinationURL = [frameworkURL URLByAppendingPathComponent:@"Smilies.sqlite"];
    
    NSMutableDictionary *newMetadata;
    if (SmilieTextsDifferBetweenStoresAtURLs(self.storeURL, destinationURL)) {
        NSError *error;
        NSDictionary *oldMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:destinationURL error:&error];
        NSAssert(oldMetadata, @"error loading metadata from %@: %@", destinationURL, error);
        NSInteger oldVersion = [oldMetadata[SmilieMetadataVersionKey] integerValue];
        
        newMetadata = [oldMetadata mutableCopy];
        newMetadata[SmilieMetadataVersionKey] = @(oldVersion + 1);
    }
    
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
    NSError *error;
    if (![[NSFileManager defaultManager] copyItemAtURL:self.storeURL toURL:destinationURL error:&error]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"replacing existing sqlite file failed" userInfo:nil];
    }
    
    if (newMetadata) {
        BOOL ok = [NSPersistentStoreCoordinator setMetadata:newMetadata forPersistentStoreOfType:NSSQLiteStoreType URL:destinationURL error:&error];
        NSAssert(ok, @"error writing metadata %@ for store at %@: %@", newMetadata, destinationURL, error);
    }
    
    [self.textView insertText:[NSString stringWithFormat:@"\n\n%@", destinationURL.path]];
}

static BOOL SmilieTextsDifferBetweenStoresAtURLs(NSURL *storeOneURL, NSURL *storeTwoURL)
{
    NSManagedObjectModel *model = [SmilieDataStore managedObjectModel];
    NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSDictionary *options = @{NSReadOnlyPersistentStoreOption: @YES};
    NSError *error;
    NSPersistentStore *storeOne = [storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:@"NoMetadata" URL:storeOneURL options:options error:&error];
    if (!storeOne) {
        NSLog(@"%s error opening store at %@: %@", __PRETTY_FUNCTION__, storeOneURL, error);
        return NO;
    }
    NSPersistentStore *storeTwo = [storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:@"NoMetadata" URL:storeTwoURL options:options error:&error];
    if (!storeTwo) {
        NSLog(@"%s error opening store at %@: %@", __PRETTY_FUNCTION__, storeTwoURL, error);
        return NO;
    }
    NSManagedObjectContext *context = [NSManagedObjectContext new];
    context.persistentStoreCoordinator = storeCoordinator;
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    fetchRequest.resultType = NSDictionaryResultType;
    fetchRequest.propertiesToFetch = @[@"text"];
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"text" ascending:YES]];
    
    fetchRequest.affectedStores = @[storeOne];
    NSArray *storeOneTexts = [context executeFetchRequest:fetchRequest error:&error];
    if (!storeOneTexts) {
        NSLog(@"%s error fetching texts from store at %@: %@", __PRETTY_FUNCTION__, storeOneURL, error);
        return NO;
    }
    
    fetchRequest.affectedStores = @[storeTwo];
    NSArray *storeTwoTexts = [context executeFetchRequest:fetchRequest error:&error];
    if (!storeTwoTexts) {
        NSLog(@"%s error fetching texts from store at %@: %@", __PRETTY_FUNCTION__, storeTwoURL, error);
        return NO;
    }
    
    return ![storeOneTexts isEqual:storeTwoTexts];
}

@end
