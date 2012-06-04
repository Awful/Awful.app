//
//  ReloadingWebViewController.h
//  Awful
//
//  Created by Nolan Waite on 12-05-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ReloadingWebViewController : UIViewController

// Designated initializer.
- (id)initWithTemplate:(NSURL *)template;

@property (readonly, strong, nonatomic) NSURL *template;

@end
