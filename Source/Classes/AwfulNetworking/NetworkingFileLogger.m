//
//  NetworkingFileLogger.m
//  Awful
//
//  Created by Nolan Waite on 12-05-20.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NetworkingFileLogger.h"

@interface NetworkingFileLogFormatter : DDLogFileFormatterDefault

@end

@implementation NetworkingFileLogger

- (id)init
{
    DDLogFileManagerDefault *manager = [[DDLogFileManagerDefault alloc] init];
    manager.maximumNumberOfLogFiles = 1;
    self = [super initWithLogFileManager:manager];
    if (self)
    {
        self.logFormatter = [[NetworkingFileLogFormatter alloc] init];
        self.maximumFileSize = 1024 * 1024 * 10;
    }
    return self;
}

@end

@implementation NetworkingFileLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    if (logMessage->logContext != NETWORK_LOG_CONTEXT)
        return nil;
    return [super formatLogMessage:logMessage];
}

@end