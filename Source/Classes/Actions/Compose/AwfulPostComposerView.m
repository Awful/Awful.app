//
//  AwfulPostComposerView.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerView.h"
#import "AwfulEmote.h"
#import "NSData+Base64.h"

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
    [self format:@"Bold"];
}

-(void) italic {
    [self format:@"Italic"];
}

-(void) underline {
    [self format:@"Underline"];
}

-(NSString*) html {
    return [self stringByEvaluatingJavaScriptFromString:@"document.getElementById('content').innerHTML"];
}

-(void)format:(NSString *)format {
    [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.execCommand(\"%@\")", format]];
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
    NSString *tag = [NSString stringWithFormat:@"<img class=\"emote\" alt=\"%@\" src=\"data:image/gif;base64,%@\" />", emote.code, emote.imageData.base64EncodedString];
    tag = [tag stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    NSString *script = [NSString stringWithFormat:@"document.execCommand('insertHTML', false, '%@')",tag];
    NSLog(@"execCommand:%@", [self stringByEvaluatingJavaScriptFromString:script]);
}

@end
