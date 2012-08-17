//
//  AwfulLoadPrevControl.m
//  Awful
//
//  Created by me on 8/15/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLoadPrevControl.h"

@implementation AwfulLoadPrevControl
-(void) changeLabelTextForCurrentState {
    //webview's tag is the current page
    //this control is in the scrollview of the webview
    NSInteger currentPage = self.superview.superview.tag;
    
    switch (self.state) {
            
        case AwfulRefreshControlStateNormal:
            self.title.text = [NSString stringWithFormat:@"Top of page %i", currentPage];
            self.subtitle.text = [NSString stringWithFormat:@"Pull down for page %i", currentPage-1];
            break;
            
        case AwfulRefreshControlStatePulling:
            self.title.text = [NSString stringWithFormat:@"Top of page %i", currentPage];
            self.subtitle.text = [NSString stringWithFormat:@"Keep pulling for page %i", currentPage-1];
            break;
            
        case AwfulRefreshControlStateLoading:
            self.title.text = [NSString stringWithFormat:@"Loading page..."];
            self.subtitle.text = @"Swipe left to cancel";
            break;
            
            
        case AwfulRefreshControlStateParsing:
            self.title.text = [NSString stringWithFormat:@"Formatting page..."];
            self.subtitle.text = nil;
            break;
            
        case AwfulRefreshControlStatePageTransition:
            self.title.text = [NSString stringWithFormat:@"kthxbye"];
            self.subtitle.text = nil;
            self.imageView2.hidden = YES;
            break;
    }
}


@end
