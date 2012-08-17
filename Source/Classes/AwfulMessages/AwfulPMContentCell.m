//
//  AwfulPMContentCell.m
//  Awful
//
//  Created by me on 8/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPMContentCell.h"
#import "AwfulPM.h"

@implementation AwfulPMContentCell
@synthesize webview = _webview;

-(void) setDictionary:(NSDictionary *)dictionary {
    [super setDictionary:dictionary];
    
    AwfulPM* message = (AwfulPM*)[dictionary objectForKey:@"AwfulPostCellPMKey"];
    
    self.detailTextLabel.text = message.content;
    
    if (!message.content)
        [message addObserver:self
                forKeyPath:AwfulPMAttributes.content
                   options:(NSKeyValueObservingOptionNew)
                     context:nil
         ];
    
    [self.webview loadHTMLString:message.content baseURL:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    //self.detailTextLabel.text = [change objectForKey:NSKeyValueChangeNewKey];
    [self.webview loadHTMLString:[change objectForKey:NSKeyValueChangeNewKey] baseURL:nil];
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.webview.frame = self.contentView.frame;
    self.webview.foX = 0;
    self.contentView.clipsToBounds = YES;
}

-(UIWebView*) webview {
    if (!_webview) {
        _webview = [UIWebView new];
        [self.contentView addSubview:_webview];
    }
    return _webview;
}
@end
