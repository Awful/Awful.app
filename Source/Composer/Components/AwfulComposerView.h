//
//  AwfulComposerView.h
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulComposerInputAccessoryView.h"
@class AwfulEmoticonKeyboardController;

@protocol AwfulComposerViewDelegate <UITextViewDelegate>

- (void)insertImage;
- (void)insertEmoticon;
- (AwfulEmoticonKeyboardController*)emoticonChooser;

@end

@interface AwfulComposerView : UITextView <AwfulComposerInputAccessoryViewDelegate,AwfulEmoticonChooserDelegate>{
    @protected
    UIWebView *_innerWebView;
    UIControl* _keyboardInputAccessory;
}

@property (nonatomic, readonly) NSString* html;
@property (nonatomic, readonly) NSString* bbcode;
@property (nonatomic, readonly,strong) UIControl* keyboardInputAccessory;
@property (nonatomic, readonly) UIWebView* innerWebView;

@end

@interface AwfulComposerTableViewCell : UITableViewCell
@property (nonatomic,strong) AwfulComposerView* composerView;
@end