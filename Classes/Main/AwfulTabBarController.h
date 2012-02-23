//
//  AwfulTabBarController.h
//  Awful
//
//  Created by Sean Berry on 2/13/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulNetworkEngine;
@class AwfulForumsList;

@interface AwfulTabBarController : UITabBarController <UITabBarControllerDelegate>

@property (nonatomic, strong) AwfulNetworkEngine *awfulNetworkEngine;
@property (nonatomic, strong) AwfulForumsList *awfulForumsList;

@end
