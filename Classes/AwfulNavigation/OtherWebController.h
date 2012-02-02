//
//  OtherWebController.h
//  Awful
//
//  Created by Sean Berry on 9/12/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface OtherWebController : UIViewController <UIWebViewDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) UIBarButtonItem *activity;
@property (nonatomic, strong) UIWebView *web;
@property (nonatomic, strong) UIBarButtonItem *backButton;
@property (nonatomic, strong) UIBarButtonItem *forwardButton;
@property BOOL openedApp;

-(id)initWithURL : (NSURL *)aUrl;
-(void)loadToolbar;

-(void)goBack;
-(void)goForward;
-(void)refreshPage;
-(void)openInSafari;
-(void)hitDone;
@end
