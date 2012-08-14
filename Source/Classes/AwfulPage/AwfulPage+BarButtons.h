//
//  AwfulPage+ButtonActions.h
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage.h"

@interface AwfulPage (BarButtons)

-(void)updatePagesLabel;
- (void)updateBookmarked;

-(void)nextPage;
-(void)prevPage;
-(void)hidePageNavigation;

-(IBAction)tappedCompose : (id)sender;
-(IBAction)tappedActions:(id)sender;
-(IBAction)tappedPageNav : (id)sender;
-(IBAction)tappedNextPage : (id)sender;

-(IBAction)segmentedGotTapped : (id)sender;
-(IBAction)tappedPagesSegment : (id)sender;
-(IBAction)tappedActionsSegment : (id)sender;
@end
