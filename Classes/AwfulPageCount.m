//
//  AwfulPageCount.m
//  Awful
//
//  Created by Regular Berry on 6/14/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageCount.h"

@implementation AwfulPageCount

@synthesize currentPage = _currentPage;
@synthesize totalPages = _totalPages;

-(id)init
{
    _currentPage = -1;
    _totalPages = -1;
    return self;
}

-(NSString *)description
{
    if(self.totalPages != -1) {
        return [NSString stringWithFormat:@"pg %d of %d", self.currentPage, self.totalPages];
    }
    return [NSString stringWithFormat:@"pg %d", self.currentPage];
}

@end