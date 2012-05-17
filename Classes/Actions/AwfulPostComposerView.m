//
//  AwfulPostComposerView.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerView.h"
#import "AwfulEmote.h"

@implementation AwfulPostComposerView

- (void) awakeFromNib
{
    [super awakeFromNib];
        
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *indexFileURL = [bundle URLForResource:@"editor" withExtension:@"html"];
        [self loadRequest:[NSURLRequest requestWithURL:indexFileURL]];
        
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emoteChosen:) name:NOTIFY_EMOTE_SELECTED object:nil];
}

-(void) bold {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand(\"Bold\")"];
}

-(void) italic {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand(\"Italic\")"];
}

-(void) underline {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand(\"Underline\")"];
}

-(NSString*) html {
    return [self stringByEvaluatingJavaScriptFromString:@"document.getElementById('content').innerHTML"];
}

-(NSString*) bbcode {
    NSMutableString *html = [NSMutableString stringWithString:self.html];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<(/?)([buis])>" 
                                                                           options:0 
                                                                             error:nil];
    
    [regex replaceMatchesInString:html
                          options:0
                            range:NSMakeRange(0, html.length)
                     withTemplate:@"[$1$2]"];
    //NSLog(@"%d matches", matches);
    
    return html;
}

-(void) emoteChosen:(NSNotification*)notification {
    AwfulEmote *emote = notification.object;
    NSString *tag = [NSString stringWithFormat:@"<img alt=\"%@\" src=\"data:image/gif;base64,%@\" />", emote.code, emote.imageData.base64EncodedString];
    tag = [tag stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    NSString *script = [NSString stringWithFormat:@"document.execCommand('insertHTML', false, '%@')",tag];
    NSLog(@"execCommand:%@", [self stringByEvaluatingJavaScriptFromString:script]);
}

@end
