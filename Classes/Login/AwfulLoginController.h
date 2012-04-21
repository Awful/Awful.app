//
//  AwfulLoginController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulSettingsViewController;

@interface AwfulLoginController : UIViewController <UIWebViewDelegate>

@property (nonatomic, strong) IBOutlet UIWebView *web;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *act;
@property (nonatomic, weak) AwfulSettingsViewController *accountViewController;

-(IBAction)hitCancel : (id)sender;

@end

extern BOOL IsLoggedIn();
