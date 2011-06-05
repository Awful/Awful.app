//
//  LoginController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulNavController.h"

@class AwfulNavController;

@interface LoginController : UIViewController <UIWebViewDelegate> {
    UIWebView *web;
    UIActivityIndicatorView *act;
}

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil controller : (AwfulNavController *)controller;
@property (nonatomic, retain) IBOutlet UIWebView *web;

-(IBAction)hitCancel;

@end
