//
//  NSURL+OpensInBrowser.h
//  Awful
//
//  Created by Nolan Waite on 2012-12-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSURL (OpensInBrowser)

// Returns YES if this URL would normally open in Safari, or NO otherwise.
- (BOOL)opensInBrowser;

@end
