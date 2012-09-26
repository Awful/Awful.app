//
//  AwfulPage+Transitions.h
//  Awful
//
//  Created by me on 5/15/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage.h"

@interface AwfulPage (Transitions)

-(void) doPageTransition;
-(void) reloadTransition;
-(void) pageForwardTransition;
-(void) pageBackTransition;
-(void) didFinishPageTransition;
@end
