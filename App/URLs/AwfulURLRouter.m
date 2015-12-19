//  AwfulURLRouter.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulURLRouter.h"
#import "AwfulForumsClient.h"
#import "EmptyViewController.h"
#import <JLRoutes/JLRoutes.h>
#import <MRProgress/MRProgressOverlayView.h>
#import "PostsPageViewController.h"
#import "RapSheetViewController.h"
#import "SettingsViewController.h"
#import "Awful-Swift.h"

@implementation AwfulURLRouter
{
    JLRoutes *_routes;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController managedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if ((self = [super init])) {
        _rootViewController = rootViewController;
        _managedObjectContext = managedObjectContext;
    }
    return self;
}

- (instancetype)init
{
    NSAssert(nil, @"Use -initWithRootViewController:managedObjectContext: instead");
    return [self initWithRootViewController:nil managedObjectContext:nil];
}

- (JLRoutes *)routes
{
    if (_routes) return _routes;
    _routes = [JLRoutes new];
    __weak __typeof__(self) weakSelf = self;
    
    #pragma mark /forums/:forumID
    [_routes addRoute:@"/forums/:forumID" handler:^(NSDictionary *parameters) {
        __typeof__(self) self = weakSelf;
        ForumKey *key = [[ForumKey alloc] initWithForumID:parameters[@"forumID"]];
        Forum *forum = [Forum existingObjectForKey:key inManagedObjectContext:self.managedObjectContext];
        if (forum) {
            return [self jumpToForum:forum];
        } else {
            return NO;
        }
    }];
    
    #pragma mark /forums
    [_routes addRoute:@"/forums" handler:^BOOL(NSDictionary *parameters) {
        return !![weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[ForumsTableViewController class]];
    }];
    
    #pragma mark /threads/:threadID/pages/:page
    [_routes addRoute:@"/threads/:threadID/pages/:page" handler:^(NSDictionary *parameters) {
        return [weakSelf showThreadWithParameters:parameters];
    }];
    
    #pragma mark /threads/:threadID
    [_routes addRoute:@"/threads/:threadID" handler:^(NSDictionary *parameters) {
        return [weakSelf showThreadWithParameters:parameters];
    }];
    
    #pragma mark /posts/:postID
    [_routes addRoute:@"/posts/:postID" handler:^(NSDictionary *parameters) {
        __typeof__(self) self = weakSelf;
        PostKey *key = [[PostKey alloc] initWithPostID:parameters[@"postID"]];
        Post *post = [Post existingObjectForKey:key inManagedObjectContext:self.managedObjectContext];
        if (post && post.page > 0) {
            PostsPageViewController *postsViewController = [[PostsPageViewController alloc] initWithThread:post.thread];
            [postsViewController loadPage:post.page updatingCache:YES updatingLastReadPost:YES];
            [postsViewController scrollPostToVisible:post];
            return [self showPostsViewController:postsViewController];
        }
        
        MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.rootViewController.view
                                                                             title:@"Locating Post"
                                                                              mode:MRProgressOverlayViewModeIndeterminate
                                                                          animated:YES];
        overlay.tintColor = [Theme currentTheme][@"tintColor"];
        __weak __typeof__(self) weakSelf = self;
        [[AwfulForumsClient client] locatePostWithID:key.postID andThen:^(NSError *error, Post *post, AwfulThreadPage page) {
            __typeof__(self) self = weakSelf;
            if (error) {
                overlay.titleLabelText = @"Post Not Found";
                overlay.mode = MRProgressOverlayViewModeCross;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [overlay dismiss:YES];
                });
            } else {
                [overlay dismiss:YES completion:^{
                    PostsPageViewController *postsViewController = [[PostsPageViewController alloc] initWithThread:post.thread];
                    [postsViewController loadPage:page updatingCache:YES updatingLastReadPost:YES];
                    [postsViewController scrollPostToVisible:post];
                    [self showPostsViewController:postsViewController];
                    NSError *error;
                    if (![self.managedObjectContext save:&error]) {
                        NSLog(@"%s error saving managed object context: %@", __PRETTY_FUNCTION__, error);
                    }
                }];
            }
        }];
        return YES;
    }];
    
    #pragma mark /messages/:messageID
    [_routes addRoute:@"/messages/:messageID" handler:^(NSDictionary *parameters) {
        __typeof__(self) self = weakSelf;
        MessageListViewController *inbox = [self selectTopmostViewControllerContainingViewControllerOfClass:[MessageListViewController class]];
        if (!inbox) {
            return NO;
        }
        [inbox.navigationController popToViewController:inbox animated:NO];
        
        PrivateMessageKey *messageKey = [[PrivateMessageKey alloc] initWithMessageID:parameters[@"messageID"]];
        PrivateMessage *message = [PrivateMessage objectForKey:messageKey inManagedObjectContext:self.managedObjectContext];
        if (message) {
            [inbox showMessage:message];
            return YES;
        }
        
        MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.rootViewController.view
                                                                             title:@"Locating Message"
                                                                              mode:MRProgressOverlayViewModeIndeterminate
                                                                          animated:YES];
        overlay.tintColor = [Theme currentTheme][@"tintColor"];
        [[AwfulForumsClient sharedClient] readPrivateMessageWithKey:messageKey andThen:^(NSError *error, PrivateMessage *message) {
            if (error) {
                overlay.titleLabelText = @"Message Not Found";
                overlay.mode = MRProgressOverlayViewModeCross;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [overlay dismiss:YES];
                });
            } else {
                [overlay dismiss:YES completion:^{
                    [inbox showMessage:message];
                }];
            }
        }];
        return YES;
    }];
    
    #pragma mark /messages
    [_routes addRoute:@"/messages" handler:^BOOL(NSDictionary *parameters) {
        return !![weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[MessageListViewController class]];
    }];
    
    #pragma mark /bookmarks
    [_routes addRoute:@"/bookmarks" handler:^BOOL(NSDictionary *parameters) {
        return !![weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[BookmarksTableViewController class]];
    }];
    
    #pragma mark /settings
    [_routes addRoute:@"/settings" handler:^BOOL(NSDictionary *parameters) {
        return !![weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[SettingsViewController class]];
    }];
    
    #pragma mark /users/:userID
    [_routes addRoute:@"/users/:userID" handler:^(NSDictionary *parameters) {
        __typeof__(self) self = weakSelf;
        void (^success)() = ^(User *user) {
            ProfileViewController *profile = [[ProfileViewController alloc] initWithUser:user];
            [self.rootViewController presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
        };
        UserKey *key = [[UserKey alloc] initWithUserID:parameters[@"userID"] username:nil];
        User *user = [User existingObjectForKey:key inManagedObjectContext:self.managedObjectContext];
        if (user) {
            success(user);
            return YES;
        }
        [[AwfulForumsClient client] profileUserWithID:key.userID username:nil andThen:^(NSError *error, Profile *profile) {
            if (profile) {
                success(profile.user);
            } else if (error) {
                [self.rootViewController presentViewController:[UIAlertController alertWithTitle:@"Could Not Find User" error:error] animated:YES completion:nil];
            }
        }];
        return YES;
    }];
	
	#pragma mark /banlist/:userID
	[_routes addRoute:@"/banlist/:userID" handler:^BOOL(NSDictionary *parameters) {
		__typeof__(self) self = weakSelf;
		
		void (^success)() = ^(User *user) {
			RapSheetViewController *rapSheet = [[RapSheetViewController alloc] initWithUser:user];
			[self.rootViewController presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
		};
        UserKey *key = [[UserKey alloc] initWithUserID:parameters[@"userID"] username:nil];
        User *user = [User existingObjectForKey:key inManagedObjectContext:self.managedObjectContext];
		if (user) {
			success(user);
			return YES;
		}
		
		[[AwfulForumsClient client] profileUserWithID:key.userID username:nil andThen:^(NSError *error, Profile *profile) {
			if (profile) {
				success(profile.user);
			} else if (error) {
                [self.rootViewController presentViewController:[UIAlertController alertWithTitle:@"Could Not Find User" error:error] animated:YES completion:nil];
			}
		}];
		return YES;
	}];
	
    #pragma mark /banlist
	[_routes addRoute:@"/banlist" handler:^BOOL(NSDictionary *parameters) {
		__typeof__(self) self = weakSelf;
		
		RapSheetViewController *rapSheet = [[RapSheetViewController alloc] initWithUser:nil];
		[self.rootViewController presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
		
		return YES;
	}];
    
    return _routes;
}

- (void)doneWithProfile
{
    [self.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)jumpToForum:(Forum *)forum
{
    ThreadsTableViewController *threadList = [self.rootViewController awful_firstDescendantViewControllerOfClass:[ThreadsTableViewController class]];
    if ([threadList.forum isEqual:forum]) {
        [threadList.navigationController popToViewController:threadList animated:YES];
        return !![self selectTopmostViewControllerContainingViewControllerOfClass:threadList.class];
    } else {
        ForumsTableViewController *forumsList = [self.rootViewController awful_firstDescendantViewControllerOfClass:[ForumsTableViewController class]];
        [forumsList.navigationController popToViewController:forumsList animated:NO];
        [forumsList openForum:forum animated:NO];
        return !![self selectTopmostViewControllerContainingViewControllerOfClass:forumsList.class];
    }
}

- (id)selectTopmostViewControllerContainingViewControllerOfClass:(Class)class
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.rootViewController;
    UITabBarController *tabBarController = splitViewController.viewControllers.firstObject;
    for (UIViewController *topmost in tabBarController.viewControllers) {
        UIViewController *match = [topmost awful_firstDescendantViewControllerOfClass:class];
        if (match) {
            tabBarController.selectedViewController = topmost;
            [splitViewController awful_showPrimaryViewController];
            return match;
        }
    }
    return nil;
}

- (BOOL)showThreadWithParameters:(NSDictionary *)parameters
{
    // TODO don't unilaterally create a thread based on the ID. If we don't already know of it, try to fetch it.
    ThreadKey *threadKey = [[ThreadKey alloc] initWithThreadID:parameters[@"threadID"]];
    Thread *thread = [Thread objectForKey:threadKey inManagedObjectContext:self.managedObjectContext];
    PostsPageViewController *postsViewController;
    NSString *userID = parameters[@"userid"];
    if (userID.length > 0) {
        UserKey *userKey = [[UserKey alloc] initWithUserID:userID username:nil];
        User *user = [User objectForKey:userKey inManagedObjectContext:self.managedObjectContext];
        postsViewController = [[PostsPageViewController alloc] initWithThread:thread author:user];
    } else {
        postsViewController = [[PostsPageViewController alloc] initWithThread:thread];
    }
    NSError *error;
    if (![self.managedObjectContext save:&error]) {
        NSLog(@"%s error saving managed object context: %@", __PRETTY_FUNCTION__, error);
    }
    NSString *pageString = parameters[@"page"];
    AwfulThreadPage page = AwfulThreadPageNone;
    if (userID.length == 0) {
        if ([pageString isEqualToString:@"last"]) {
            page = AwfulThreadPageLast;
        } else if ([pageString isEqualToString:@"unread"]) {
            page = AwfulThreadPageNextUnread;
        }
    }
    if (page == AwfulThreadPageNone) {
        page = pageString.integerValue ?: thread.beenSeen ? AwfulThreadPageNextUnread : 1;
    }
    [postsViewController loadPage:page updatingCache:YES updatingLastReadPost:YES];
    if (parameters[@"post"]) {
        PostKey *postKey = [[PostKey alloc] initWithPostID:parameters[@"post"]];
        [postsViewController scrollPostToVisible:[Post objectForKey:postKey inManagedObjectContext:self.managedObjectContext]];
    }
    return [self showPostsViewController:postsViewController];
}

- (BOOL)showPostsViewController:(PostsPageViewController *)postsViewController
{
    postsViewController.restorationIdentifier = @"Posts from URL";
    
    // Showing a posts view controller as a result of opening a URL is not the same as simply showing a detail view controller. We want to push it on to an existing navigation stack. Which one depends on how the split view is currently configured.
    UINavigationController *targetNavigationController;
    UISplitViewController *splitViewController = (UISplitViewController *)self.rootViewController;
    if (splitViewController.viewControllers.count == 2) {
        targetNavigationController = splitViewController.viewControllers[1];
    } else {
        UITabBarController *tabBarController = splitViewController.viewControllers[0];
        targetNavigationController = (UINavigationController *)tabBarController.selectedViewController;
    }
    
    // If the detail view controller is empty, showing the posts view controller actually is as simple as showing a detail view controller, and we can exit early.
    if ([targetNavigationController.topViewController isKindOfClass:[EmptyViewController class]]) {
        [splitViewController showDetailViewController:postsViewController sender:self];
        return YES;
    }
    
    // Posts view controllers by default hide the bottom bar when pushed. This moves the tab bar controller's tab bar out of the way, making room for the toolbar. However, if some earlier posts view controller has already done this for us, and we went ahead oblivious, we would hide our own toolbar!
    if ([targetNavigationController.topViewController isKindOfClass:[PostsPageViewController class]]) {
        postsViewController.hidesBottomBarWhenPushed = NO;
    }
    
    [targetNavigationController pushViewController:postsViewController animated:YES];
    return YES;
}

- (BOOL)routeURL:(NSURL *)URL
{
    if ([URL.scheme caseInsensitiveCompare:@"awful"] != NSOrderedSame) return NO;
    return [self.routes routeURL:URL];
}

@end
