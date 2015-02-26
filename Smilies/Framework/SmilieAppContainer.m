//  SmilieAppContainer.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieAppContainer.h"

static NSString * const AppGroupIdentifier = @"group.com.awfulapp.SmilieKeyboard";

static NSUserDefaults * SharedDefaults(void)
{
    return [[NSUserDefaults alloc] initWithSuiteName:AppGroupIdentifier];
}

static NSString * const AwfulAppIsActiveKey = @"SmilieAwfulAppIsActive";

BOOL SmilieKeyboardIsAwfulAppActive(void)
{
    return [SharedDefaults() boolForKey:AwfulAppIsActiveKey];
}

void SmilieKeyboardSetIsAwfulAppActive(BOOL isActive)
{
    [SharedDefaults() setBool:isActive forKey:AwfulAppIsActiveKey];
}

static NSString * const SelectedSmilieListKey = @"SmilieSelectedSmilieList";

SmilieList SmilieKeyboardSelectedSmilieList(void)
{
    return [SharedDefaults() integerForKey:SelectedSmilieListKey];
}

void SmilieKeyboardSetSelectedSmilieList(SmilieList smilieList)
{
    [SharedDefaults() setInteger:smilieList forKey:SelectedSmilieListKey];
}

static NSString * ScrollFractionKey(SmilieList smilieList)
{
    return [NSString stringWithFormat:@"SmilieScrollFraction%@", @(smilieList)];
}

float SmilieKeyboardScrollFractionForSmilieList(SmilieList smilieList)
{
    return [SharedDefaults() floatForKey:ScrollFractionKey(smilieList)];
}

void SmilieKeyboardSetScrollFractionForSmilieList(SmilieList smilieList, float scrollFraction)
{
    [SharedDefaults() setFloat:scrollFraction forKey:ScrollFractionKey(smilieList)];
}

NSURL * SmilieKeyboardSharedContainerURL(void)
{
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:AppGroupIdentifier];
}

BOOL SmilieKeyboardHasFullAccess(void)
{
    return [[NSFileManager defaultManager] isReadableFileAtPath:SmilieKeyboardSharedContainerURL().path];
}
