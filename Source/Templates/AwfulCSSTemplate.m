//
//  AwfulCSSTemplate.m
//  Awful
//
//  Created by Nolan Waite on 12-06-14.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCSSTemplate.h"

@interface NSString (AwfulRegex)

- (NSString *)awful_firstMatchForRegex:(NSString *)regex
                               options:(NSRegularExpressionOptions)options
                                 group:(NSUInteger)group;

- (NSArray *)awful_firstMatchForRegex:(NSString *)regex
                              options:(NSRegularExpressionOptions)options
                               groups:(NSIndexSet *)groups;

@end

@implementation AwfulCSSTemplate

- (id)initWithURL:(NSURL *)url error:(NSError **)error
{
    self = [super init];
    if (self) {
        _URL = url;
        _CSS = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
        if (!_CSS) {
            return nil;
        }
    }
    return self;
}

@end


@implementation AwfulCSSTemplate (Settings)

+ (AwfulCSSTemplate *)currentTemplate
{
    return CommonCSSLoader([[AwfulSettings settings] darkTheme] ? @"dark" : @"default");
}

+ (AwfulCSSTemplate *)defaultTemplate
{
    return CommonCSSLoader(@"default");
}

static AwfulCSSTemplate *CommonCSSLoader(NSString *basename)
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:basename withExtension:@"css"];
    NSError *error;
    AwfulCSSTemplate *css = [[AwfulCSSTemplate alloc] initWithURL:url error:&error];
    if (!css) {
        NSLog(@"error loading current template %@: %@", url, error);
    }
    return css;
}

@end
