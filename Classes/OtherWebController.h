//
//  OtherWebController.h
//  Awful
//
//  Created by Sean Berry on 9/12/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface OtherWebController : UIViewController <UIWebViewDelegate> {
    NSURL *url;
    UIBarButtonItem *activity;
    UIWebView *web;
    
    UIBarButtonItem *back;
    UIBarButtonItem *forward;
    BOOL sprung;
}

-(id)initWithURL : (NSURL *)in_url;
-(void)loadToolbar;

-(void)goBack;
-(void)goForward;
-(void)refreshPage;
-(void)openInSafari;
-(void)hitDone;

@property (nonatomic, retain) NSURL *url;

@end
