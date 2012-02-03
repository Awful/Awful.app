//
//  AwfulPageCount.h
//  Awful
//
//  Created by Regular Berry on 6/14/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulPageCount : NSObject

@property int currentPage;
@property int totalPages;

-(BOOL)onLastPage;
-(NSUInteger)getPagesLeft;

@end
