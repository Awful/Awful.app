//
//  AwfulComposerView.h
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulComposerView : UITextView {
    @protected
    UIWebView *_innerWebView;
    UIControl* _keyboardInputAccessory;
}
/*
-(void) bold;
-(void) italic;
-(void) underline;
-(void) strike;
-(void) spoiler;
-(void) format:(NSString*)format;
*/
@property (nonatomic, readonly) NSString* html;
@property (nonatomic, readonly) NSString* bbcode;
@property (nonatomic, readonly,strong) UIControl* keyboardInputAccessory;
@property (nonatomic, readonly) UIWebView* innerWebView;

@end
