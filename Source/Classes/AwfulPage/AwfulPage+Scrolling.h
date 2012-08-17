//
//  AwfulPage+Scrolling.h
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage.h"

@interface AwfulPage (Scrolling)

-(void)scrollToSpecifiedPost;
-(void)scrollToPost : (NSString *)post_id;
-(void)scrollToBottom;
@end
