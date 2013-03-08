//
//  AwfulErrorDomain.m
//  Awful
//
//  Created by Nolan Waite on 2013-03-08.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulErrorDomain.h"

NSString * const AwfulErrorDomain = @"AwfulErrorDomain";

const struct AwfulErrorCodes AwfulErrorCodes = {
    .badUsernameOrPassword = -1000,
    .threadIsClosed = -1001,
    .parseError = -1002,
};
