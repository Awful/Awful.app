//
//  AwfulSettings.m
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSettings.h"

@interface AwfulSettings ()

@property (strong) NSArray *sections;

@end

@implementation AwfulSettings

+ (AwfulSettings *)settings
{
    static AwfulSettings *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithResource:@"Settings"];
    });
    return instance;
}

- (id)initWithResource:(NSString *)basename
{
    self = [super init];
    if (self)
    {
        NSURL *url = [[NSBundle mainBundle] URLForResource:basename withExtension:@"plist"];
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfURL:url];
        self.sections = [plist objectForKey:@"Sections"];
    }
    return self;
}

- (void)registerDefaults
{
    NSArray *listOfSettings = [self.sections valueForKeyPath:@"@unionOfArrays.Settings"];
    NSMutableDictionary *defaults = [NSMutableDictionary new];
    for (NSDictionary *setting in listOfSettings) {
        NSString *key = [setting objectForKey:@"Key"];
        id value = [setting objectForKey:@"Default"];
        if (key && value) {
            [defaults setObject:value forKey:key];
        }
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

@synthesize sections = _sections;

@end
