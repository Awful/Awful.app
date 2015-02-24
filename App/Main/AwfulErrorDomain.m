//  AwfulErrorDomain.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulErrorDomain.h"

NSString * const AwfulErrorDomain = @"AwfulErrorDomain";

const struct AwfulErrorCodes AwfulErrorCodes = {
    .badUsernameOrPassword = 1,
    .threadIsClosed = 2,
    .parseError = 3,
    .dataMigrationError = 4,
    .missingDataStore = 5,
    .forbidden = 6,
    .databaseUnavailable = 7,
    .archivesRequired = 8,
    .badServerResponse = NSURLErrorBadServerResponse,
};
