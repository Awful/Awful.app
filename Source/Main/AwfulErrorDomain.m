//  AwfulErrorDomain.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulErrorDomain.h"

NSString * const AwfulErrorDomain = @"AwfulErrorDomain";

const struct AwfulErrorCodes AwfulErrorCodes = {
    .badUsernameOrPassword = -1000,
    .threadIsClosed = -1001,
    .parseError = -1002,
    .dataMigrationError = -1003,
    .missingDataStore = -1004,
    .forbidden = -1005,
    .databaseUnavailable = -1006,
    .archivesRequired = -1007,
};
