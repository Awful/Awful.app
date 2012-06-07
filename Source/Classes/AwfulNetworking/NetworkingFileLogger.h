//
//  NetworkingFileLogger.h
//  Awful
//
//  Created by Nolan Waite on 12-05-20.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DDFileLogger.h"

#define NETWORK_LOG_CONTEXT 100

#define NetworkLogInfo(f, ...) \
        ASYNC_LOG_OBJC_MAYBE(NetworkLogLevel, LOG_FLAG_INFO, NETWORK_LOG_CONTEXT, f, ##__VA_ARGS__)

@interface NetworkingFileLogger : DDFileLogger

@end
