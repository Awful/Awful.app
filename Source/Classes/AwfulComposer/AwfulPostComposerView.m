//
//  AwfulPostComposerView.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerView.h"
#import "AwfulPostComposerInputAccessoryView.h"
#import "AwfulEmote.h"
#import "AwfulEmotePickerController.h"

@implementation AwfulPostComposerView
@synthesize keyboardInputAccessory = _keyboardInputAccessory;
@synthesize innerWebView = _innerWebView;
- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    _innerWebView = [[UIWebView alloc] initWithFrame:frame];
    _innerWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _innerWebView.backgroundColor = [UIColor magentaColor];
    
    [self addSubview:_innerWebView];
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *indexFileURL = [bundle URLForResource:@"editor" withExtension:@"html"];
    [_innerWebView loadRequest:[NSURLRequest requestWithURL:indexFileURL]];
        

    //self.inputAccessoryView = self.keyboardInputAccessory;
    NSLog(@"%@",self.innerWebView.inputAccessoryView);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emoteChosen:) name:AwfulEmoteChosenNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(keyboardWillShowOrHide:)
                                                 name:UIKeyboardWillShowNotification 
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShowOrHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    return self;
}

-(UIView*)keyboardInputAccessory {
    if (!_keyboardInputAccessory) {
        _keyboardInputAccessory = [[AwfulPostComposerInputAccessoryView alloc] initWithFrame:CGRectMake(0, 0, 400, 44)];
    }
    [_keyboardInputAccessory addTarget:self action:@selector(keyboardInputAccessoryFormat:) forControlEvents:AwfulControlEventPostComposerFormat];
    
    
    return _keyboardInputAccessory;
}

#pragma formatting
-(void) keyboardInputAccessoryFormat:(AwfulPostComposerInputAccessoryView*)postComposerAccessory {
    switch (postComposerAccessory.formatState) {
        case AwfulPostFormatBold:
            [self format:@"Bold"];
            break;
            
        case AwfulPostFormatItalic:
            [self format:@"Italic"];
            break;
            
        case AwfulPostFormatUnderline:
            [self format:@"Underline"];
            break;
            
            
        default:
            break;
    }
}

-(void)format:(NSString *)format {
    [self.innerWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand(\"%@\")", format]];
}

#pragma mark accessing user input
-(NSString*) html {
    NSString* html = [self.innerWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('content').innerHTML"];
    return html;
}


-(NSString*) bbcode {
    NSMutableString *html = [NSMutableString stringWithString:self.html];
    
    //replace html formatting
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<(/?)([buis])>" 
                                                                           options:0 
                                                                             error:nil];
    [regex replaceMatchesInString:html
                          options:0
                            range:NSMakeRange(0, html.length)
                     withTemplate:@"[$1$2]"];
    
    
    //replace emotes
    regex = [NSRegularExpression regularExpressionWithPattern:@"<img src=.*? class=\"emote\" alt=\"(.*)\">"
                                                      options:0 
                                                        error:nil];
    [regex replaceMatchesInString:html
                          options:0
                            range:NSMakeRange(0, html.length)
                     withTemplate:@"$1"];
    
    //non-emote image replacement
    //for plat users attaching an image, skip in bbcode, upload via http
    
    //for inline images:
    //image picker provides local url.  editor will show that
    //after choosing, image uploaded to host of choice
    //when successful, need to store the returned url somewhere, maybe in the img tag
    //disable send button until all image uploads are done
    //convert to bbcode using the host url
    
    return html;
}


-(void) emoteChosen:(NSNotification*)notification {
    AwfulEmote *emote = notification.object;
    //[self insertText:emote.code];
    
    NSString* path = [[NSBundle mainBundle] pathForResource:emote.filename.lastPathComponent ofType:nil];
    
    [self.innerWebView stringByEvaluatingJavaScriptFromString:
     //[NSString stringWithFormat:@"document.execCommand('insertImage', false, '%@')", path]
     [NSString stringWithFormat:@"document.execCommand('insertHTML', false, '<img src=\"%@\" class=\"emote\" alt=\"%@\" >')", path, emote.code]
     ];
    
    //[imagePickerPopover dismissPopoverAnimated:YES];
    //i++;
    //NSString *tag = [NSString stringWithFormat:@"<img class=\"emote\" alt=\"%@\" src=\"data:image/gif;base64,%@\" />", emote.code, emote.imageData.base64EncodedString];
    //tag = [tag stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    //NSString *script = [NSString stringWithFormat:@"document.execCommand('insertHTML', false, '%@')",tag];
    //NSLog(@"execCommand:%@", [self stringByEvaluatingJavaScriptFromString:script]);
}

#pragma mark keyboard handling
-(void) keyboardWillShowOrHide:(NSNotification*)notification {
    NSLog(@"%@",notification.object);
    //uiwebview has a built in inputAccessory that can't be changed
    //that's p dumb, this covers it up with self.keyboardinputaccessory
    
    UIWindow* keyboardWindow = [self getKeyboardWindow];
    
    CGRect keyboardFrame = [(NSValue*)[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardOrigin = [[notification.userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    
    self.keyboardInputAccessory.frame = CGRectMake(0.0f, keyboardOrigin.origin.y, keyboardFrame.size.width, 44.0f);

    [UIView animateWithDuration:0.25 animations:^{
        self.keyboardInputAccessory.foY = keyboardFrame.origin.y;
    }];

   // CGFloat keyboardWidth = [notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey].size.width;
    
    [keyboardWindow addSubview:self.keyboardInputAccessory];
}

-(UIWindow*) getKeyboardWindow {
    for (UIWindow *testWindow in [[UIApplication sharedApplication] windows]) {
        if (![[testWindow class] isEqual:[UIWindow class]]) {
            return testWindow;
            break;
        }
    }
    return nil;
}



#pragma mark AwfulWebViewDelegate Protocol
-(void) webView:(UIWebView *)webView pageDidRequestAction:(NSString *)action infoDictionary:(NSDictionary *)infoDictionary {
    NSLog(@"here");
}

@end
