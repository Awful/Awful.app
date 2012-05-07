//
//  AwfulPostComposerView.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerView.h"

@implementation AwfulPostComposerView

- (void) awakeFromNib
{
    [super awakeFromNib];
        
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *indexFileURL = [bundle URLForResource:@"editor" withExtension:@"html"];
        [self loadRequest:[NSURLRequest requestWithURL:indexFileURL]];
        
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
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<(/?)([bui])>" 
                                                                           options:0 
                                                                             error:nil];
    
    int matches = [regex replaceMatchesInString:html
                          options:0
                            range:NSMakeRange(0, html.length)
                     withTemplate:@"[$1$2]"];
    //NSLog(@"%d matches", matches);
    
    return html;
}

@end
