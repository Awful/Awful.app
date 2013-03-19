//
//  AwfulErrorDomain.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulErrorDomain.h"

NSString * const AwfulErrorDomain = @"AwfulErrorDomain";

const struct AwfulErrorCodes AwfulErrorCodes = {
    .badUsernameOrPassword = -1000,
    .threadIsClosed = -1001,
    .parseError = -1002,
    .dataMigrationError = -1003,
};
