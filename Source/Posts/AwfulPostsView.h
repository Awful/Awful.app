//  AwfulPostsView.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
@protocol AwfulPostsViewDelegate;
#import <WebViewJavascriptBridge.h>

@interface AwfulPostsView : UIView

- (id)initWithFrame:(CGRect)frame baseURL:(NSURL *)baseURL;

@property (readonly, strong, nonatomic) NSURL *baseURL;

@property (weak, nonatomic) id <AwfulPostsViewDelegate> delegate;

- (void)reloadData;

- (void)jumpToElementWithID:(NSString *)elementID;

@property (readonly, assign, nonatomic) CGFloat scrolledFractionOfContent;

- (void)scrollToFractionOfContent:(CGFloat)fraction;

@property (readonly, nonatomic) UIScrollView *scrollView;

@property (readonly, strong, nonatomic) UIWebView *webView;

@property (readonly, strong, nonatomic) WebViewJavascriptBridge *webViewJavaScriptBridge;

@end

@protocol AwfulPostsViewDelegate <NSObject>

- (NSString *)HTMLForPostsView:(AwfulPostsView *)postsView;

- (void)postsView:(AwfulPostsView *)postsView willFollowLinkToURL:(NSURL *)url;

@end
