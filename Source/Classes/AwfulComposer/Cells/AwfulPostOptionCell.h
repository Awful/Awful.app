//
//  AwfulPostOptionsCell.h
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulPostCell.h"

typedef enum {
    AwfulPostOptionCellParseURLs,
    AwfulPostOptionCellBookmark,
    AwfulPostOptionCellSmilies,
    AwfulPostOptionCellSignature
} AwfulPostOptions;

@interface AwfulPostOptionCell : AwfulPostCell

@end
