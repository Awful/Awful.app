//
//  AwfulPageParser.h
//  Awful
//
//  Created by Sean Berry on 2/1/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulPageParser : NSObject

@property (nonatomic, strong) NSMutableArray *posts;
@property (nonatomic, strong) NSString *html;

@end
