//  AwfulPostsView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import "AwfulPostsViewTopBar.h"

/**
 * An AwfulPostsView wraps a UIWebView, which reacts poorly to a contentInset, in a UIScrollView which has no such reaction.
 *
 * Specifically, when a UIWebView has a contentInset, elements' bounding rects seem to be adjusted but `document.elementFromPoint` doesn't consider this. Since it returns null if either argument is negative, some visible elements will never be returned. rdar://16925474
 *
 * We want to use a top contentInset for showing the top bar. Since that won't work, an AwfulPostsView will fake it for us.
 */
@interface AwfulPostsView : UIView

@property (readonly, strong, nonatomic) UIWebView *webView;

@property (readonly, strong, nonatomic) AwfulPostsViewTopBar *topBar;

@end
