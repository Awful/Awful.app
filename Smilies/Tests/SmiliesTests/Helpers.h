//  Helpers.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;
@import Smilies;
@import WebArchive;
@import XCTest;

extern SmilieWebArchive * FixtureWebArchive(void);

@interface TestDataStore : SmilieDataStore

+ (instancetype)newNothingBundledDataStore;

@end
