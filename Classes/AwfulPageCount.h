//
//  AwfulPageCount.h
//  Awful
//
//  Created by Regular Berry on 6/14/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulPageCount : NSObject
{
    int _currentPage;
    int _totalPages;
}

@property int currentPage;
@property int totalPages;

@end
