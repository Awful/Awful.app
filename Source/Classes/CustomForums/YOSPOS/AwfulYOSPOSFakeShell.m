//
//  AwfulYOSPOSFakeShell.m
//  Awful
//
//  Created by me on 8/9/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulYOSPOSFakeShell.h"
#import "AwfulUser+AwfulMethods.h"

@implementation AwfulYOSPOSFakeShell
@synthesize history = _history;
@synthesize currentCommand = _currentCommand;
@synthesize label = _label;

-(id) initWithLabel:(UILabel*)label {
    self = [super init];
    _label = label;
    _history = @"";
    [self update];
    
    return self;
}

-(NSString*) prompt {
    return [NSString stringWithFormat:@"yospos:~ %@$", [[AwfulUser currentUser] userName]];
}

-(void) update {
    self.label.text = [NSString stringWithFormat:@"%@%@ %@", self.history, self.prompt, self.currentCommand];
}

-(void) setCurrentCommand:(NSString *)currentCommand {
    _currentCommand = currentCommand;
    [self update];
}

-(void) execute {
    //state = executing
    _history = [self.history stringByAppendingFormat:@"%@ %@\n", self.prompt, self.currentCommand];
    
    NSString* output = @"Command not found: xxxxxx";
    _history = [self.history stringByAppendingFormat:@"%@%@\n", self.history, output];
    
    [self update];
}

-(void) wget {
    
    
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
}

@end
