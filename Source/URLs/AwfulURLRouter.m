//  AwfulURLRouter.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulURLRouter.h"
#import "AwfulForumsClient.h"
#import "AwfulModels.h"
#import "BookmarkedThreadListViewController.h"
#import "EmptyViewController.h"
#import "ForumListViewController.h"
#import <JLRoutes/JLRoutes.h>
#import "MessageListViewController.h"
#import <MRProgress/MRProgressOverlayView.h>
#import "PostsPageViewController.h"
#import "RapSheetViewController.h"
#import "SettingsViewController.h"
#import "ThreadListViewController.h"
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

- (JLRoutes *)routes
{
    if (_routes) return _routes;
    _routes = [JLRoutes new];
    __weak __typeof__(self) weakSelf = self;
    
    [_routes addRoute:@"/forums/:forumID" handler:^(NSDictionary *parameters) {
        __typeof__(self) self = weakSelf;
        NSString *forumID = parameters[@"forumID"];
        AwfulForum *forum = [AwfulForum fetchArbitraryInManagedObjectContext:self.managedObjectContext matchingPredicateFormat:@"forumID = %@", forumID];
        if (forum) {
            return [self jumpToForum:forum];
        } else {
            return NO;
        }
    }];
    
    [_routes addRoute:@"/forums" handler:^(NSDictionary *parameters) {
        return [weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[ForumListViewController class]];
    }];
    
    [_routes addRoute:@"/threads/:threadID/pages/:page" handler:^(NSDictionary *parameters) {
        return [weakSelf showThreadWithParameters:parameters];
    }];
    
    [_routes addRoute:@"/threads/:threadID" handler:^(NSDictionary *parameters) {
        return [weakSelf showThreadWithParameters:parameters];
    }];
    
    [_routes addRoute:@"/posts/:postID" handler:^(NSDictionary *parameters) {
        __typeof__(self) self = weakSelf;
        NSString *postID = parameters[@"postID"];
        Post *post = [Post fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                        matchingPredicateFormat:@"postID = %@", postID];
        if (post && post.page > 0) {
            PostsPageViewController *postsViewController = [[PostsPageViewController alloc] initWithThread:post.thread];
            [postsViewController loadPage:post.page updatingCache:YES];
            [postsViewController scrollPostToVisible:post];
            return [self showPostsViewController:postsViewController];
        }
        
        MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.rootViewController.view
                                                                             title:@"Locating Post"
                                                                              mode:MRProgressOverlayViewModeIndeterminate
                                                                          animated:YES];
        overlay.tintColor = [AwfulTheme currentTheme][@"tintColor"];
        __weak __typeof__(self) weakSelf = self;
        [[AwfulForumsClient client] locatePostWithID:postID andThen:^(NSError *error, Post *post, AwfulThreadPage page) {
            __typeof__(self) self = weakSelf;
            if (error) {
                overlay.titleLabelText = @"Post Not Found";
                overlay.mode = MRProgressOverlayViewModeCross;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [overlay dismiss:YES];
                });
            } else {
                [overlay dismiss:YES completion:^{
                    AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:post.thread.threadID
                                                             inManagedObjectContext:self.managedObjectContext];
                    PostsPageViewController *postsViewController = [[PostsPageViewController alloc] initWithThread:thread];
                    [postsViewController loadPage:page updatingCache:YES];
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
    
    [_routes addRoute:@"/messages" handler:^(NSDictionary *parameters) {
        return [weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[MessageListViewController class]];
    }];
    
    [_routes addRoute:@"/bookmarks" handler:^BOOL(NSDictionary *parameters) {
        return [weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[BookmarkedThreadListViewController class]];
    }];
    
    [_routes addRoute:@"/settings" handler:^BOOL(NSDictionary *parameters) {
        return [weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[SettingsViewController class]];
    }];
    
    [_routes addRoute:@"/users/:userID" handler:^BOOL(NSDictionary *parameters) {
        __typeof__(self) self = weakSelf;
        void (^success)(AwfulUser *) = ^(AwfulUser *user) {
            ProfileViewController *profile = [[ProfileViewController alloc] initWithUser:user];
            [self.rootViewController presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
        };
        AwfulUser *user = [AwfulUser fetchArbitraryInManagedObjectContext:self.managedObjectContext matchingPredicateFormat:@"userID = %@", parameters[@"userID"]];
        if (user) {
            success(user);
            return YES;
        }
        [[AwfulForumsClient client] profileUserWithID:parameters[@"userID"] username:nil andThen:^(NSError *error, AwfulUser *user) {
            if (user) {
                success(user);
            } else if (error) {
                [self.rootViewController presentViewController:[UIAlertController alertWithTitle:@"Could Not Find User" error:error] animated:YES completion:nil];
            }
        }];
        return YES;
    }];
	
	[_routes addRoute:@"/banlist" handler:^BOOL(NSDictionary *parameters) {
		__typeof__(self) self = weakSelf;
		
		RapSheetViewController *rapSheet = [[RapSheetViewController alloc] initWithUser:nil];
		[self.rootViewController presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
		
		return YES;
	}];
	
	
	[_routes addRoute:@"/banlist/:userID" handler:^BOOL(NSDictionary *parameters) {
		__typeof__(self) self = weakSelf;
		
		void (^success)(AwfulUser *) = ^(AwfulUser *user) {
			RapSheetViewController *rapSheet = [[RapSheetViewController alloc] initWithUser:user];
			[self.rootViewController presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
		};
		AwfulUser *user = [AwfulUser fetchArbitraryInManagedObjectContext:self.managedObjectContext matchingPredicateFormat:@"userID = %@", parameters[@"userID"]];
		if (user) {
			success(user);
			return YES;
		}
		
		[[AwfulForumsClient client] profileUserWithID:parameters[@"userID"] username:nil andThen:^(NSError *error, AwfulUser *user) {
			if (user) {
				success(user);
			} else if (error) {
                [self.rootViewController presentViewController:[UIAlertController alertWithTitle:@"Could Not Find User" error:error] animated:YES completion:nil];
			}
		}];
		return YES;
	}];
    
    return _routes;
}

- (void)doneWithProfile
{
    [self.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)jumpToForum:(AwfulForum *)forum
{
    ThreadListViewController *threadList = [self.rootViewController awful_firstDescendantViewControllerOfClass:[ThreadListViewController class]];
    if ([threadList.forum isEqual:forum]) {
        [threadList.navigationController popToViewController:threadList animated:YES];
        return [self selectTopmostViewControllerContainingViewControllerOfClass:threadList.class];
    } else {
        ForumListViewController *forumsList = [self.rootViewController awful_firstDescendantViewControllerOfClass:[ForumListViewController class]];
        [forumsList.navigationController popToViewController:forumsList animated:NO];
        [forumsList showForum:forum animated:NO];
        return [self selectTopmostViewControllerContainingViewControllerOfClass:forumsList.class];
    }
}

- (BOOL)selectTopmostViewControllerContainingViewControllerOfClass:(Class)class
{
    UISplitViewController *splitViewController = (UISplitViewController *)self.rootViewController;
    UITabBarController *tabBarController = splitViewController.viewControllers.firstObject;
    for (UIViewController *topmost in tabBarController.viewControllers) {
        if ([topmost awful_firstDescendantViewControllerOfClass:class]) {
            tabBarController.selectedViewController = topmost;
            [splitViewController awful_showPrimaryViewController];
            return YES;
        }
    }
    return NO;
}

- (BOOL)showThreadWithParameters:(NSDictionary *)parameters
{
    NSString *threadID = parameters[@"threadID"];
    AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID
                                             inManagedObjectContext:self.managedObjectContext];
    PostsPageViewController *postsViewController;
    NSString *userID = parameters[@"userid"];
    if (userID.length > 0) {
        AwfulUser *user = [AwfulUser firstOrNewUserWithUserID:userID username:nil inManagedObjectContext:self.managedObjectContext];
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
    [postsViewController loadPage:page updatingCache:YES];
    return [self showPostsViewController:postsViewController];
}

- (BOOL)showPostsViewController:(PostsPageViewController *)postsViewController
{
    postsViewController.restorationIdentifier = @"Posts from URL";
    
    // Showing a posts view controller as a result of opening a URL is not the same as simply showing a detail view controller. We want to push it on to an existing navigation stack. Which one depends on how the split view is currently configured.
    UINavigationController *targetNavigationController;
    UISplitViewController *splitViewController = (UISplitViewController *)self.rootViewController;
    if (splitViewController.collapsed) {
        UITabBarController *tabBarController = splitViewController.viewControllers.firstObject;
        targetNavigationController = (UINavigationController *)tabBarController.selectedViewController;
    } else {
        targetNavigationController = splitViewController.viewControllers.lastObject;
        
        // If the detail view controller is empty, showing the posts view controller actually is as simple as showing a detail view controller, and we can exit early.
        if ([targetNavigationController awful_firstDescendantViewControllerOfClass:[EmptyViewController class]]) {
            [splitViewController showDetailViewController:postsViewController sender:self];
            return YES;
        }
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
