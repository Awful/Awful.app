//
//  AwfulLoginController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulLoginController : UIViewController <UIWebViewDelegate> {
    UIWebView *_web;
    UIActivityIndicatorView *_act;
}

@property (nonatomic, strong) IBOutlet UIWebView *web;
@property (nonatomic, strong) UIActivityIndicatorView *act;

@end

BOOL isLoggedIn();