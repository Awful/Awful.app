//  SmilieAppContainer.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieAppContainer.h"

static NSString * const AppGroupIdentifier = @"group.com.awfulapp.SmilieKeyboard";

static NSUserDefaults * SharedDefaults(void)
{
    return [[NSUserDefaults alloc] initWithSuiteName:AppGroupIdentifier];
}

static NSString * const AwfulAppIsActiveKey = @"AwfulAppIsActive";

BOOL SmilieKeyboardIsAwfulAppActive(void)
{
    return [SharedDefaults() boolForKey:AwfulAppIsActiveKey];
}

void SmilieKeyboardSetIsAwfulAppActive(BOOL isActive)
{
    [SharedDefaults() setBool:isActive forKey:@"AwfulAppIsActive"];
}

NSURL * SmilieKeyboardSharedContainerURL(void)
{
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:AppGroupIdentifier];
}
