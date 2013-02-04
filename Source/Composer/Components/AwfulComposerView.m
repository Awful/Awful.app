//
//  AwfulComposerView.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposerView.h"
#import "AwfulComposerInputAccessoryView.h"
#import "AwfulEmoticonChooserViewController.h"
#import "AwfulComposerViewController.h"

@implementation AwfulComposerView
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
        

    self.inputAccessoryView = self.keyboardInputAccessory;
    NSLog(@"%@",self.innerWebView.inputAccessoryView);
    
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emoteChosen:) name:AwfulEmoteChosenNotification object:nil];
    
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
        _keyboardInputAccessory = [[AwfulComposerInputAccessoryView alloc] initWithFrame:CGRectMake(0, 0, 400, 44)];
        [(AwfulComposerInputAccessoryView*)_keyboardInputAccessory setDelegate:self];
    }
 
    return _keyboardInputAccessory;
}

- (BOOL)becomeFirstResponder
{
    [self.innerWebView becomeFirstResponder];
    return YES;
}

#pragma mark formatting

-(void) setFormat:(AwfulPostFormatStyle)format {
    switch (format) {
        case AwfulPostFormatBold:
            [self format:@"Bold"];
            break;
            
        case AwfulPostFormatItalic:
            [self format:@"Italic"];
            break;
            
        case AwfulPostFormatUnderline:
            [self format:@"Underline"];
            break;
            
        case AwfulPostFormatSpoil:
            [self spoil];
            break;
            
            
        default:
            break;
    }
}

-(void)format:(NSString *)format {
    [self.innerWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand(\"%@\")", format]];
}

-(void)insertString:(NSString *)string {
    [self.innerWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand(\"insertText\", false, \"%@\")", string]];
}

- (void)spoil {
    [self.innerWebView stringByEvaluatingJavaScriptFromString:@"spoilerSelectedText()"];
}

-(void)insertImage:(int)imageType {
    switch (imageType) {
        case 0: //image
            NSLog(@"text:%@", self.bbcode);
            [(id<AwfulComposerViewDelegate>)self.delegate insertImage];
            break;
            
        case 1: //emoticon
            //[self showEmoticonChooser];
            break;
    }
}

- (void)showEmoticonChooser {
    AwfulEmoticonKeyboardController* chooser = [AwfulEmoticonKeyboardController new];
    chooser.delegate = self;
    NSError *error;
    NSString* position = [self.innerWebView stringByEvaluatingJavaScriptFromString:@"getCaretClientPosition()"];
    NSArray *pos = [NSJSONSerialization JSONObjectWithData:[position dataUsingEncoding:NSUTF8StringEncoding]
                                                        options:0
                                                          error:&error];
    
    _pop = [[UIPopoverController alloc] initWithContentViewController:chooser];
    [_pop presentPopoverFromRect:CGRectMake([pos[0] intValue], [pos[1] intValue], 10, 10)
                         inView:self.innerWebView
       permittedArrowDirections:(UIPopoverArrowDirectionAny)
                       animated:YES];
    
    
}

- (void)didChooseEmoticon:(id)emoticon
{
    NSString *localURL = [[NSBundle mainBundle] pathForResource:@"emot-v" ofType:@"gif"];
    [self.innerWebView stringByEvaluatingJavaScriptFromString:
     [NSString stringWithFormat:@"document.execCommand(\"insertHTML\", false, \"<img src='%@' title='title'/>\")", localURL]];
}

#pragma mark accessing user input
-(NSString*) html {
    NSString* html = [self.innerWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('content').innerHTML"];
    return html;
}

- (NSString*)text {
    return self.html;
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
    
    //replace spoilers
    regex = [NSRegularExpression regularExpressionWithPattern:@"<span class=\"spoiler\">(.*?)</span>"
                                                      options:0
                                                        error:nil];
    [regex replaceMatchesInString:html
                          options:0
                            range:NSMakeRange(0, html.length)
                     withTemplate:@"[spoiler]$1[/spoiler]"];
    
    
    
    //replace emotes
    regex = [NSRegularExpression regularExpressionWithPattern:@"<img src=.*? class=\"emote\" alt=\"(.*)\">"
                                                      options:0 
                                                        error:nil];
    [regex replaceMatchesInString:html
                          options:0
                            range:NSMakeRange(0, html.length)
                     withTemplate:@"$1"];
    

    //images, etc
    
    return html;
}

/*
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
*/
#pragma mark keyboard handling
-(void) keyboardWillShowOrHide:(NSNotification*)notification {
    //uiwebview has a built in inputAccessory that can't be changed
    //that's p dumb, this covers it up with self.keyboardinputaccessory
    
    UIWindow* keyboardWindow = [self getKeyboardWindow];
    
    CGRect keyboardFrame = [(NSValue*)[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardOrigin = [[notification.userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    
    self.keyboardInputAccessory.frame = CGRectMake(0.0f, keyboardOrigin.origin.y, keyboardFrame.size.width, 44.0f);

    [UIView animateWithDuration:0.25 animations:^{
        CGRect frame = self.keyboardInputAccessory.frame;
        frame.origin.y = keyboardFrame.origin.y;
        self.keyboardInputAccessory.frame = frame;
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

@implementation AwfulComposerTableViewCell

- (id)init {
    self = [super initWithStyle:(UITableViewCellStyleDefault) reuseIdentifier:[self.class description]];
    //_composerView = [AwfulComposerView new];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.composerView.frame = self.contentView.frame;
    [self.contentView addSubview:self.composerView];
}

@end
