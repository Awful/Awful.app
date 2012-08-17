//
//  YosposhCommand-wget.m
//  Awful
//
//  Created by me on 8/10/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "YosposhCommand_wget.h"
#import "AwfulYOSPOSHTTPRequestOperation.h"

@implementation YosposhCommand_wget

-(id) initWithArgs:(NSArray *)args shell:(AwfulYOSPOSFakeShell *)shell {
    self = [super initWithArgs:args shell:shell];
    

    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didGetHTTPResopnse:)
                                                 name:AwfulYOSPOSHTTPRequestNotification
                                               object:nil
     ];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didGetHTTPData:)
                                                 name:AwfulYOSPOSHTTPDataNotification
                                               object:nil
     ];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didFinishNetworkOperation:)
                                                 name:AFNetworkingOperationDidFinishNotification
                                               object:nil
     ];
    
    [self.shell outputLine:@"--[datetime]--  http://forums.somethingawful.com:80/forumdisplay.php?forumid=219\n"
        @"Connecting to forums.somethingawful.com|:80... connected.\n"
        @"HTTP Request sent, awaiting response... "
     ];
    
    /*
    NSArray *wgetOutputArray = [NSArray arrayWithObjects:
                                @"--13:30:45--  http://forums.somethingawful.com:80/forumdisplay.php?forumid=219\n",
                                @"Connecting to forums.somethingawful.com|:80... connected.\n",
                                @"HTTP request sent, awaiting response... 200 OK.\n",
                                @"Length: unspecified [text/html]\n",
                                @"Saving to 'forumdisplay.php?yospos=bitch\n",
                                @"\n",
                                @"     0K .......... .......... .......... 160K\n",
                                @"    50K .......... ...\n",
                                @"\n",
                                @"13:30:46 (68.32K/s) - `index.html' saved [1749/1749]",
                                nil
                                ];
    */
    return self;
}

-(void) didGetHTTPResopnse:(NSNotification*)notification {
    NSNumber* code = [notification.userInfo objectForKey:@"code"];
    NSString *output = [NSString stringWithFormat:@"%@ OK.\n"
                        @"Length: unspecified [text/html]\n"
                        @"Saving to 'forumdisplay.php?yospos=bitch\n",
                        code
                        ];
    [self.shell outputLine:output];
}

-(void) didGetHTTPData:(NSNotification*)notification {
    NSNumber* length = [notification.userInfo objectForKey:@"length"];
    [self.shell output:@"."];
}

-(void) didFinishNetworkOperation:(NSNotification*)notification {
    [self.shell outputLine:@"\n[datetime] (speedK/s) - `forumdisplay.php?yospos=bitch' saved [size/size]"
     ];
    
    [self done];
}

-(void) done {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super done];
}

@end
