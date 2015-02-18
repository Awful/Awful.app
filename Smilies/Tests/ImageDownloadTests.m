//  ImageDownloadTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Helpers.h"
#import "SmilieOperation.h"

@interface ImageDownloadTests : XCTestCase

@end

@interface FixtureWebArchiveURLProtocol : NSURLProtocol

@end

@implementation ImageDownloadTests

- (void)setUp
{
    [super setUp];
    [NSURLProtocol registerClass:[FixtureWebArchiveURLProtocol class]];
}

- (void)tearDown
{
    [NSURLProtocol unregisterClass:[FixtureWebArchiveURLProtocol class]];
    [super tearDown];
}

- (void)testDownloadTwoImages
{
    SmilieDataStore *dataStore = [TestDataStore new];
    Smilie *forwardToWork = [Smilie newInManagedObjectContext:dataStore.managedObjectContext];
    forwardToWork.text = @"!forwardtowork!";
    forwardToWork.imageURL = @"http://i.somethingawful.com/forumsystem/emoticons/emot-backtowork.gif";
    Smilie *realColbert = [Smilie newInManagedObjectContext:dataStore.managedObjectContext];
    realColbert.text = @"!colbert!";
    realColbert.imageURL = @"http://i.somethingawful.com/forumsystem/emoticons/emot-crossarms.gif";
    NSError *error;
    if (![forwardToWork.managedObjectContext save:nil]) {
        NSAssert(NO, @"error saving new smilies: %@", error);
    }
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"imageData = nil"];
    NSUInteger precount = [dataStore.managedObjectContext countForFetchRequest:fetchRequest error:&error];
    XCTAssertEqual(precount, 2U, @"possible error: %@", error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"downloading image data"];
    SmilieDownloadMissingImageDataOperation *operation = [[SmilieDownloadMissingImageDataOperation alloc] initWithDataStore:dataStore URLSession:nil];
    
    // Can't just -waitUntilFinished as core data fetches/saves run through the main thread.
    operation.completionBlock = ^{
        [expectation fulfill];
    };
    [operation start];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(forwardToWork.imageData);
    XCTAssertNotNil(realColbert.imageData);
}

@end

@interface FixtureWebArchiveURLProtocol ()

@property (strong, nonatomic) SmilieWebArchive *webArchive;

@end

@implementation FixtureWebArchiveURLProtocol

+ (SmilieWebArchive *)webArchive
{
    static SmilieWebArchive *webArchive;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        webArchive = FixtureWebArchive();
    });
    return webArchive;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSData *data = [[[self class] webArchive] dataForSubresourceWithURL:self.request.URL];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                              statusCode:(data ? 200 : 404)
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:nil];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (data) {
        [self.client URLProtocol:self didLoadData:data];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
    // no-op
}

@end
