//
//  AwfulWebViewDelegate.h
//  Awful
//
//  Created by Nolan Waite on 12-05-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AwfulWebViewDelegate <UIWebViewDelegate, NSObject>

// Sent when a script on the page calls into the bridge we set up.
- (void)webView:(UIWebView *)webView
pageDidRequestAction:(NSString *)action
 infoDictionary:(NSDictionary *)infoDictionary;

-(void)webViewDidFinishLoad:(UIWebView *)sender;

@end

// Redirects script calls into the bridge, and otherwise passes everything through.
@interface AwfulWebViewDelegateWrapper : NSObject <UIWebViewDelegate>

+ (id <UIWebViewDelegate>)delegateWrappingDelegate:(id <AwfulWebViewDelegate>)delegate;

@end
