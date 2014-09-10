//  AwfulPostPreviewViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostPreviewViewController.h"
#import "AwfulComposeTextView.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulLoadingView.h"
#import "AwfulPostViewModel.h"
#import "AwfulSelfHostingAttachmentInterpolator.h"
#import "AwfulSettings.h"
#import "AwfulTextAttachment.h"
#import <GRMustache/GRMustache.h>
#import "Awful-Swift.h"

@interface AwfulPostPreviewViewController () <UIWebViewDelegate>

@property (strong, nonatomic) UIBarButtonItem *postButtonItem;

@property (strong, nonatomic) AwfulLoadingView *loadingView;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (strong, nonatomic) AwfulSelfHostingAttachmentInterpolator *imageInterpolator;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) AwfulPost *fakePost;

@end

@implementation AwfulPostPreviewViewController
{
    BOOL _webViewDidLoadOnce;
    AwfulPost *_fakePost;
}

- (id)initWithPost:(AwfulPost *)post BBcode:(NSAttributedString *)BBcode
{
    if ((self = [self initWithBBcode:BBcode])) {
        _editingPost = post;
        self.postButtonItem.title = @"Save";
    }
    return self;
}

- (id)initWithThread:(AwfulThread *)thread BBcode:(NSAttributedString *)BBcode
{
    if ((self = [self initWithBBcode:BBcode])) {
        _thread = thread;
    }
    return self;
}

- (id)initWithBBcode:(NSAttributedString *)BBcode
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _BBcode = [BBcode copy];
        self.title = @"Post Preview";
        self.navigationItem.rightBarButtonItem = self.postButtonItem;
    }
    return self;
}

- (UIBarButtonItem *)postButtonItem
{
    if (_postButtonItem) return _postButtonItem;
    _postButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Post" style:UIBarButtonItemStylePlain target:nil action:nil];
    __weak __typeof__(self) weakSelf = self;
    _postButtonItem.awful_actionBlock = ^(UIBarButtonItem *item) {
        __typeof__(self) self = weakSelf;
        self.submitBlock();
    };
    return _postButtonItem;
}

- (UIWebView *)webView
{
    return (UIWebView *)self.view;
}

- (void)loadView
{
    UIWebView *webView = [UIWebView awful_nativeFeelingWebView];
    webView.delegate = self;
    self.view = webView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.loadingView = [AwfulLoadingView loadingViewForTheme:self.theme];
}

- (AwfulTheme *)theme
{
    AwfulThread *thread = self.thread ?: self.editingPost.thread;
    return [AwfulTheme currentThemeForForum:thread.forum];
}

- (void)themeDidChange
{
    [super themeDidChange];
    
    AwfulTheme *theme = self.theme;
    self.view.backgroundColor = theme[@"backgroundColor"];
    self.webView.scrollView.indicatorStyle = theme.scrollIndicatorStyle;
    
    [self renderPreview];
}

- (void)fetchPreviewIfNecessary
{
    if (self.fakePost || self.networkOperation) return;
    
    self.imageInterpolator = [AwfulSelfHostingAttachmentInterpolator new];
    NSString *interpolatedBBcode = [self.imageInterpolator interpolateImagesInString:self.BBcode];
    __weak __typeof__(self) weakSelf = self;
    void (^callback)() = ^(NSError *error, NSString *postHTML) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
        } else if (self) {
            self.fakePost = [AwfulPost insertInManagedObjectContext:self.managedObjectContext];
            AwfulUser *loggedInUser = [AwfulUser firstOrNewUserWithUserID:[AwfulSettings sharedSettings].userID
                                                                 username:[AwfulSettings sharedSettings].username
                                                   inManagedObjectContext:self.managedObjectContext];
            if (self.editingPost) {
                
                // Create a copy of the post we're editing. We'll later change the properties we care about previewing.
                for (NSPropertyDescription *property in self.editingPost.entity) {
                    if ([property isKindOfClass:[NSAttributeDescription class]]) {
                        id actualValue = [self.editingPost valueForKey:property.name];
                        [self.fakePost setValue:actualValue forKey:property.name];
                    } else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
                        NSManagedObject *actualValue = [self.editingPost valueForKey:property.name];
                        if ([[NSNull null] isEqual:actualValue]) continue;
                        NSManagedObjectID *objectID = actualValue.objectID;
                        if (objectID) {
                            [self.fakePost setValue:[self.managedObjectContext objectWithID:objectID] forKey:property.name];
                        }
                    }
                }
                
                self.fakePost.editor = loggedInUser;
            } else {
                self.fakePost.postDate = [NSDate date];
                self.fakePost.author = loggedInUser;
            }
        }
        self.fakePost.innerHTML = postHTML;
        [self renderPreview];
    };
    if (self.editingPost) {
        self.networkOperation = [[AwfulForumsClient client] previewEditToPost:self.editingPost withBBcode:interpolatedBBcode andThen:callback];
    } else {
        self.networkOperation = [[AwfulForumsClient client] previewReplyToThread:self.thread withBBcode:interpolatedBBcode andThen:callback];
    }
}

- (void)renderPreview
{
    _webViewDidLoadOnce = NO;
    [self fetchPreviewIfNecessary];
    if (!self.fakePost) return;
    
    NSMutableDictionary *context = [NSMutableDictionary new];
    context[@"userInterfaceIdiom"] = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"ipad" : @"iphone";
	context[@"version"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    context[@"stylesheet"] = self.theme[@"postsViewCSS"];
    context[@"post"] = [[AwfulPostViewModel alloc] initWithPost:self.fakePost];
    int fontScalePercentage = [AwfulSettings sharedSettings].fontScale;
    if (fontScalePercentage != 100) {
        context[@"fontScalePercentage"] = @(fontScalePercentage);
    }
    
    NSError *error;
    NSString *HTML = [GRMustacheTemplate renderObject:context fromResource:@"PostPreview" bundle:nil error:&error];
    if (!HTML) {
        NSLog(@"%s error loading post preview HTML: %@", __PRETTY_FUNCTION__, error);
    }
    [self.webView loadHTMLString:HTML baseURL:[AwfulForumsClient client].baseURL];
    
    [self.loadingView removeFromSuperview];
    self.loadingView = nil;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) return _managedObjectContext;
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    _managedObjectContext.parentContext = self.editingPost.managedObjectContext ?: self.thread.managedObjectContext;
    return _managedObjectContext;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // YouTube embeds can take over the frame when someone taps the video title. Here we try to detect that and treat it as if a link was tapped.
    if (navigationType != UIWebViewNavigationTypeLinkClicked && [request.URL.host.lowercaseString hasSuffix:@"www.youtube.com"] && [request.URL.path.lowercaseString hasPrefix:@"/watch"]) {
        navigationType = UIWebViewNavigationTypeLinkClicked;
    }
    
    return navigationType != UIWebViewNavigationTypeLinkClicked;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!_webViewDidLoadOnce) {
        _webViewDidLoadOnce = YES;
        [self.loadingView removeFromSuperview];
        self.loadingView = nil;
    }
}

@end
