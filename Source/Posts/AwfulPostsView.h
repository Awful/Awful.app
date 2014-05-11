//  AwfulPostsView.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
@protocol AwfulPostsViewDelegate;

@interface AwfulPostsView : UIView

- (id)initWithFrame:(CGRect)frame baseURL:(NSURL *)baseURL;

@property (readonly, strong, nonatomic) NSURL *baseURL;

@property (weak, nonatomic) id <AwfulPostsViewDelegate> delegate;

- (void)reloadData;

- (void)reloadPostAtIndex:(NSInteger)index withHTML:(NSString *)HTML;

- (void)prependPostsHTML:(NSString *)HTML;

- (void)clearAllPosts;

- (void)jumpToElementWithID:(NSString *)elementID;

@property (copy, nonatomic) NSString *stylesheet;

@property (nonatomic) BOOL showAvatars;

@property (nonatomic) int fontScale;

- (void)loadLinkifiedImages;

// Set to nil to highlight no mentions.
@property (copy, nonatomic) NSString *highlightMentionUsername;

- (void)setLastReadPostID:(NSString *)postID;

@property (readonly, assign, nonatomic) CGFloat scrolledFractionOfContent;

- (void)scrollToFractionOfContent:(CGFloat)fraction;

@property (readonly, nonatomic) UIScrollView *scrollView;

@property (readonly, strong, nonatomic) UIWebView *webView;

// Set to nil to hide end of thread message.
@property (copy, nonatomic) NSString *endMessage;

/**
 * Calls completionBlock with a dictionary containing keys from AwfulInterestingElementKeys.
 */
- (void)interestingElementsAtPoint:(CGPoint)point completion:(void (^)(NSDictionary *elementInfo))completionBlock;

- (CGRect)rectOfHeaderForPostAtIndex:(NSUInteger)postIndex;

- (CGRect)rectOfFooterForPostAtIndex:(NSUInteger)postIndex;

- (CGRect)rectOfActionButtonForPostAtIndex:(NSUInteger)postIndex;

@end

/**
 * Keys that may be present in the dictionary returned by -interestingElementsAtPoint:.
 */
extern const struct AwfulInterestingElementKeys {
    
    /**
     * An NSString of a URL pointing to an image.
     */
    __unsafe_unretained NSString *spoiledImageURL;
    
    /**
     * An NSDictionary with info keys "rect" and "URL".
     */
    __unsafe_unretained NSString *spoiledLinkInfo;
    
    /**
     * An NSDictionary with info keys "rect" and "URL".
     */
    __unsafe_unretained NSString *spoiledVideoInfo;
    
    // Info keys.
    
    /**
     * The CGRectFromString-formatted bounding rect of the element.
     */
    __unsafe_unretained NSString *rect;
    
    /**
     * The NSString of the URL pointing to the element's contents.
     */
    __unsafe_unretained NSString *URL;

} AwfulInterestingElementKeys;

@protocol AwfulPostsViewDelegate <NSObject>

@required

- (NSString *)HTMLForPostsView:(AwfulPostsView *)postsView;

@optional

- (void)postsView:(AwfulPostsView *)postsView willFollowLinkToURL:(NSURL *)url;

- (void)postsView:(AwfulPostsView *)postsView didTapUserHeaderWithRect:(CGRect)rect forPostAtIndex:(NSUInteger)postIndex;

- (void)postsView:(AwfulPostsView *)postsView didTapActionButtonWithRect:(CGRect)rect forPostAtIndex:(NSUInteger)postIndex;

@end
