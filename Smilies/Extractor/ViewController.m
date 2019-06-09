//  ViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ViewController.h"
@import CoreData;
@import HTMLReader;
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

- (IBAction)didTapStickers:(UIBarButtonItem *)sender
{
    self.textView.text = @"Stickering…";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self extractStickers];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.textView.text = [self.textView.text stringByAppendingString:@" done!\n\nDon't forget to scale them up!"];
        });
    });
}

- (void)extractStickers
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *stickersFolder = [SmiliesFolderURL() URLByAppendingPathComponent:@"Stickers" isDirectory:YES];
    NSURL *xcassetsFolder = [stickersFolder URLByAppendingPathComponent:@"Stickers.xcassets" isDirectory:YES];
    NSURL *stickerPackFolder = [xcassetsFolder URLByAppendingPathComponent:@"Sticker Pack.stickerpack" isDirectory:YES];
    
    NSError *error;
    BOOL ok = [fileManager createDirectoryAtURL:stickerPackFolder withIntermediateDirectories:YES attributes:nil error:&error];
    if (!ok) {
        NSLog(@"error creating sticker pack directory: %@", error);
    }
    
    // Delete old smilie stickers.
    NSEnumerator *enumerator = [fileManager enumeratorAtURL:stickerPackFolder
                                 includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                    options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                               errorHandler:nil];
    for (NSURL *subfolder in enumerator) {
        NSNumber *isDirectory;
        NSError *error;
        BOOL ok = [subfolder getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
        NSAssert(ok, @"error: %@", error);
        if (!isDirectory.boolValue) {
            continue;
        }
        ok = [fileManager removeItemAtURL:subfolder error:&error];
        NSAssert(ok, @"error: %@", error);
    }
    
    // Make new smilie stickers.
    NSMutableArray *stickers = [NSMutableArray new];
    NSSet *objectionableTexts = LoadObjectionableTexts(@"PotentiallyObjectionableStickers");
    EnumerateSmiliesInHTML(self.archive, ^(NSString *text, NSString *imageURL, NSString *section, NSString *summary, NSData *imageData) {
        if ([objectionableTexts containsObject:text]) {
            return;
        }
        
        NSString *stickerFilename = [text stringByAppendingPathExtension:@"sticker"];
        NSURL *subfolder = [stickerPackFolder URLByAppendingPathComponent:stickerFilename isDirectory:YES];
        NSError *error;
        BOOL ok = [fileManager createDirectoryAtURL:subfolder withIntermediateDirectories:YES attributes:nil error:&error];
        NSAssert(ok, @"error: %@", error);
        [stickers addObject:@{@"filename": stickerFilename}];
        
        NSString *imageFilename = imageURL.lastPathComponent;
        ok = [imageData writeToURL:[subfolder URLByAppendingPathComponent:imageFilename isDirectory:NO] atomically:NO];
        NSAssert(ok, @"couldn't write image data");
        
        NSDictionary *contents = @{@"info": @{@"version": @1, @"author": @"Smilie Extractor"},
                                   @"properties": @{@"accessibility-label": summary, @"filename": imageFilename}};
        NSData *json = [NSJSONSerialization dataWithJSONObject:contents options:0 error:&error];
        NSAssert(json, @"error: %@", error);
        ok = [json writeToURL:[subfolder URLByAppendingPathComponent:@"Contents.json" isDirectory:NO] atomically:NO];
        NSAssert(ok, @"couldn't write json data");
    });
    
    NSDictionary *contents = @{@"stickers": stickers,
                               @"info": @{@"version": @1, @"author": @"Smilie Extractor"},
                               @"properties": @{@"grid-size": @"small"}};
    NSData *json = [NSJSONSerialization dataWithJSONObject:contents options:0 error:&error];
    NSAssert(json, @"error: %@", error);
    ok = [json writeToURL:[stickerPackFolder URLByAppendingPathComponent:@"Contents.json" isDirectory:NO] atomically:NO];
    NSAssert(ok, @"couldn't write json data");
}

static NSSet * LoadObjectionableTexts(NSString *basename) {
    NSURL *objectionURL = [[NSBundle bundleForClass:[ViewController class]] URLForResource:basename withExtension:@"plist"];
    return [NSSet setWithArray:[NSArray arrayWithContentsOfURL:objectionURL]];
}

static void EnumerateSmiliesInHTML(SmilieWebArchive *webArchive, void (^block)(NSString *text, NSString *imageURL, NSString *section, NSString *summary, NSData *imageData))
{
    HTMLDocument *document = [HTMLDocument documentWithString:webArchive.mainFrameHTML];
    HTMLElement *container = [document firstNodeMatchingSelector:@".smilie_list"];
    NSArray *headers = [container nodesMatchingSelector:@"h3"];
    NSArray *lists = [container nodesMatchingSelector:@".smilie_group"];
    NSCAssert(headers.count == lists.count, @"expecting equal numbers of section headers and sections");
    [headers enumerateObjectsUsingBlock:^(HTMLElement *header, NSUInteger i, BOOL *stop) {
        HTMLElement *section = lists[i];
        for (HTMLElement *item in [section nodesMatchingSelector:@"li"]) {
            
            NSString *text = [item firstNodeMatchingSelector:@".text"].textContent;
            HTMLElement *img = [item firstNodeMatchingSelector:@"img"];
            NSString *imageURL = img[@"src"];
            NSString *section = header.textContent;
            NSString *summary = img[@"title"];
            
            NSData *imageData = [webArchive dataForSubresourceWithURL:[NSURL URLWithString:imageURL]];
            
            block(text, imageURL, section, summary, imageData);
        }
    }];
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

// Private function implemented in Smilies.framework.
extern void UpdateSmilieImageDataDerivedAttributes(Smilie *smilie);

- (void)scrapeSmiliesCompletionHandler:(void (^)(void))completionHandler
{
    [self.managedObjectContext performBlock:^{
        void (^save)() = ^{
            NSError *error;
            BOOL ok = [self.managedObjectContext save:&error];
            if (!ok) {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"could not save context" userInfo:nil];
            }
        };
        
        NSSet *objectionableTexts = LoadObjectionableTexts(@"PotentiallyObjectionableTexts");
        
        __block NSInteger i = 0;
        EnumerateSmiliesInHTML(self.archive, ^(NSString *text, NSString *imageURL, NSString *section, NSString *summary, NSData *imageData) {
            Smilie *smilie = [Smilie newInManagedObjectContext:self.managedObjectContext];
            smilie.text = text;
            smilie.imageURL = imageURL;
            smilie.potentiallyObjectionable = [objectionableTexts containsObject:text];
            smilie.section = section;
            smilie.summary = summary;
            smilie.imageData = imageData;
            
            UpdateSmilieImageDataDerivedAttributes(smilie);
            
            i += 1;
            if (i % 100 == 0) save();
        });
        
        save();
        
        if (completionHandler) dispatch_async(dispatch_get_main_queue(), completionHandler);
    }];
}

static NSURL * SmiliesFolderURL(void) {
    NSURL *thisFileURL = [NSURL fileURLWithPath:[NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding]];
    return [[thisFileURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent];
}

- (IBAction)didTapReplace:(UIBarButtonItem *)sender
{
    sender.enabled = NO;
    
    NSURL *frameworkURL = [SmiliesFolderURL() URLByAppendingPathComponent:@"Framework"];
    NSURL *destinationURL = [frameworkURL URLByAppendingPathComponent:@"Smilies.sqlite"];
    
    NSMutableDictionary *newMetadata;
    NSError *error;
    NSDictionary *oldMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:destinationURL options:nil error:&error];
    NSAssert(oldMetadata, @"error loading metadata from %@: %@", destinationURL, error);
    NSInteger oldVersion = [oldMetadata[SmilieMetadataVersionKey] integerValue];
    
    newMetadata = [oldMetadata mutableCopy];
    newMetadata[SmilieMetadataVersionKey] = @(oldVersion + 1);
    
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
    if (![[NSFileManager defaultManager] copyItemAtURL:self.storeURL toURL:destinationURL error:&error]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"replacing existing sqlite file failed" userInfo:nil];
    }
    
    BOOL ok = [NSPersistentStoreCoordinator setMetadata:newMetadata forPersistentStoreOfType:NSSQLiteStoreType URL:destinationURL options:nil error:&error];
    NSAssert(ok, @"error writing metadata %@ for store at %@: %@", newMetadata, destinationURL, error);
    
    [self.textView replaceRange:[self.textView textRangeFromPosition:self.textView.endOfDocument toPosition:self.textView.endOfDocument] withText:[NSString stringWithFormat:@"\n\n%@", destinationURL.path]];
}

@end
