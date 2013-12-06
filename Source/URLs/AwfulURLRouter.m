//  AwfulURLRouter.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulURLRouter.h"
#import "AwfulAlertView.h"
#import "AwfulBookmarkedThreadTableViewController.h"
#import "AwfulForumsListController.h"
#import "AwfulForumThreadTableViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPostsViewController.h"
#import "AwfulPrivateMessageTableViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulSettingsViewController.h"
#import <JLRoutes/JLRoutes.h>
#import <SVProgressHUD/SVProgressHUD.h>

@implementation AwfulURLRouter
{
    JLRoutes *_routes;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
            managedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super init])) return nil;
    _rootViewController = rootViewController;
    _managedObjectContext = managedObjectContext;
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
        AwfulForum *forum = [AwfulForum fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                     matchingPredicateFormat:@"forumID = %@", forumID];
        if (forum) {
            return [self jumpToForum:forum];
        } else {
            return NO;
        }
    }];
    
    [_routes addRoute:@"/forums" handler:^(NSDictionary *parameters) {
        return [weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[AwfulForumsListController class]];
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
        AwfulPost *post = [AwfulPost fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                  matchingPredicateFormat:@"postID = %@", postID];
        if (post && post.page > 0) {
            AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:post.thread];
            postsViewController.page = post.page;
            postsViewController.topPost = post;
            return [self showPostsViewController:postsViewController];
        }
        
        [SVProgressHUD showWithStatus:@"Locating Post"];
        __weak __typeof__(self) weakSelf = self;
        [AwfulHTTPClient.client locatePostWithID:postID andThen:^(NSError *error, AwfulPost *post, AwfulThreadPage page) {
            __typeof__(self) self = weakSelf;
            if (error) {
                [SVProgressHUD showErrorWithStatus:@"Post Not Found"];
                NSLog(@"%s couldn't locate post at %@: %@", __PRETTY_FUNCTION__, parameters[kJLRouteURLKey], error);
            } else {
                [SVProgressHUD dismiss];
                AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:post.thread.threadID
                                                         inManagedObjectContext:self.managedObjectContext];
                AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
                postsViewController.page = page;
                postsViewController.topPost = [AwfulPost firstOrNewPostWithPostID:postID
                                                           inManagedObjectContext:self.managedObjectContext];
                [self showPostsViewController:postsViewController];
            }
        }];
        return YES;
    }];
    
    [_routes addRoute:@"/messages" handler:^(NSDictionary *parameters) {
        return [weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[AwfulPrivateMessageTableViewController class]];
    }];
    
    [_routes addRoute:@"/bookmarks" handler:^BOOL(NSDictionary *parameters) {
        return [weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[AwfulBookmarkedThreadTableViewController class]];
    }];
    
    [_routes addRoute:@"/settings" handler:^BOOL(NSDictionary *parameters) {
        return [weakSelf selectTopmostViewControllerContainingViewControllerOfClass:[AwfulSettingsViewController class]];
    }];
    
    [_routes addRoute:@"/users/:userID" handler:^BOOL(NSDictionary *parameters) {
        __typeof__(self) self = weakSelf;
        void (^success)(AwfulUser *) = ^(AwfulUser *user) {
            AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:user];
            UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                  target:self
                                                                                  action:@selector(doneWithProfile)];
            profile.navigationItem.leftBarButtonItem = item;
            [self.rootViewController presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
        };
        AwfulUser *user = [AwfulUser firstOrNewUserWithUserID:parameters[@"userID"] username:nil inManagedObjectContext:self.managedObjectContext];
        if (user) {
            success(user);
            return YES;
        }
        __weak __typeof__(self) weakSelf = self;
        [[AwfulHTTPClient client] profileUserWithID:parameters[@"userID"] andThen:^(NSError *error, AwfulUser *user) {
            __typeof__(self) self = weakSelf;
            if (user) {
                AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:user];
                [self.rootViewController presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
            } else if (error) {
                [AwfulAlertView showWithTitle:@"Could Not Find User" error:error buttonTitle:@"OK"];
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
    AwfulForumThreadTableViewController *threadList = FindViewControllerOfClass(self.rootViewController,
                                                                                [AwfulForumThreadTableViewController class]);
    if ([threadList.forum isEqual:forum]) {
        [threadList.navigationController popToViewController:threadList animated:YES];
        return [self selectTopmostViewControllerContainingViewControllerOfClass:threadList.class];
    } else {
        AwfulForumsListController *forumsList = FindViewControllerOfClass(self.rootViewController, [AwfulForumsListController class]);
        [forumsList.navigationController popToViewController:forumsList animated:NO];
        [forumsList showForum:forum animated:NO];
        return [self selectTopmostViewControllerContainingViewControllerOfClass:forumsList.class];
    }
}

- (BOOL)selectTopmostViewControllerContainingViewControllerOfClass:(Class)class
{
    if (![self.rootViewController respondsToSelector:@selector(viewControllers)]) return NO;
    if (![self.rootViewController respondsToSelector:@selector(setSelectedViewController:)]) return NO;
    for (UIViewController *topmost in [self.rootViewController valueForKey:@"viewControllers"]) {
        if (FindViewControllerOfClass(topmost, class)) {
            [self.rootViewController setValue:topmost forKey:@"selectedViewController"];
            return YES;
        }
    }
    return NO;
}

static id FindViewControllerOfClass(UIViewController *viewController, Class class)
{
    if ([viewController isKindOfClass:class]) return viewController;
    if ([viewController respondsToSelector:@selector(viewControllers)]) {
        for (UIViewController *child in [viewController valueForKey:@"viewControllers"]) {
            UIViewController *found = FindViewControllerOfClass(child, class);
            if (found) return found;
        }
    }
    return nil;
}

- (BOOL)showThreadWithParameters:(NSDictionary *)parameters
{
    NSString *threadID = parameters[@"threadID"];
    AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID
                                             inManagedObjectContext:self.managedObjectContext];
    AwfulPostsViewController *postsViewController;
    NSString *userID = parameters[@"userid"];
    if (userID.length > 0) {
        AwfulUser *user = [AwfulUser firstOrNewUserWithUserID:userID
                                                     username:nil
                                       inManagedObjectContext:self.managedObjectContext];
        postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread author:user];
    } else {
        postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
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
    postsViewController.page = page;
    return [self showPostsViewController:postsViewController];
}

- (BOOL)showPostsViewController:(AwfulPostsViewController *)postsViewController
{
    postsViewController.restorationIdentifier = @"Posts from URL";
    if ([self.rootViewController isKindOfClass:[AwfulExpandingSplitViewController class]]) {
        AwfulExpandingSplitViewController *split = (AwfulExpandingSplitViewController *)self.rootViewController;
        split.detailViewController = postsViewController.enclosingNavigationController;
        split.detailViewController.restorationIdentifier = @"Navigation";
        return YES;
    }
    if (![self.rootViewController respondsToSelector:@selector(selectedViewController)]) return NO;
    UIViewController *selected = [self.rootViewController valueForKey:@"selectedViewController"];
    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)selected;
        [navigationController pushViewController:postsViewController animated:YES];
        return YES;
    }
    return NO;
}

- (BOOL)routeURL:(NSURL *)URL
{
    if ([URL.scheme caseInsensitiveCompare:@"awful"] != NSOrderedSame) return NO;
    return [self.routes routeURL:URL];
}

@end
