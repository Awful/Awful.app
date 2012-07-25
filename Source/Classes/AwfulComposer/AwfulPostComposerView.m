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
#import "AwfulEmoteChooser.h"


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
                                             selector:@selector(keyboardWillShow:) 
                                                 name:UIKeyboardWillShowNotification 
                                               object:nil];
    return self;
}

-(UIView*)keyboardInputAccessory {
    if (!_keyboardInputAccessory) {
        _keyboardInputAccessory = [[AwfulPostComposerInputAccessoryView alloc] initWithFrame:CGRectMake(0, 0, 400, 44)];
    }
    return _keyboardInputAccessory;
}


-(void) bold {
    [self format:@"Bold"];
}
 
-(void) italic {
    [self format:@"Italic"];
}

-(void) underline {
    [self format:@"Underline"];
}

-(NSString*) html {
    return [self.innerWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('content').innerHTML"];
}

-(void)format:(NSString *)format {
    [self.innerWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand(\"%@\")", format]];
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
    regex = [NSRegularExpression regularExpressionWithPattern:@"<img class=\"emote\" alt=\"(.*)\" src=.*?>" 
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
     [NSString stringWithFormat:@"document.execCommand('insertImage', false, '%@')", path]
     ];
    
    //[imagePickerPopover dismissPopoverAnimated:YES];
    //i++;
    //NSString *tag = [NSString stringWithFormat:@"<img class=\"emote\" alt=\"%@\" src=\"data:image/gif;base64,%@\" />", emote.code, emote.imageData.base64EncodedString];
    //tag = [tag stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    //NSString *script = [NSString stringWithFormat:@"document.execCommand('insertHTML', false, '%@')",tag];
    //NSLog(@"execCommand:%@", [self stringByEvaluatingJavaScriptFromString:script]);
}

-(void) keyboardWillShow:(NSNotification*)notification {
    UIWindow* keyboardWindow;
    
    for (UIWindow *testWindow in [[UIApplication sharedApplication] windows]) {
        if (![[testWindow class] isEqual:[UIWindow class]]) {
            keyboardWindow = testWindow;
            break;
        }
    }
    
    CGRect keyboardFrame = [(NSValue*)[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardOrigin = [[notification.userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    
    self.keyboardInputAccessory.frame = CGRectMake(0.0f, keyboardOrigin.origin.y, keyboardFrame.size.width, 44.0f);

    [UIView animateWithDuration:0.25 animations:^{
        self.keyboardInputAccessory.foY = keyboardFrame.origin.y;
    }];

   // CGFloat keyboardWidth = [notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey].size.width;
    
    [keyboardWindow addSubview:self.keyboardInputAccessory];
}

@end
