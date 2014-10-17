//  SmilieAppContainer.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
#import <Smilies/SmilieListType.h>

/*
 This user default is part of an attempt to make the keyboard extension useful when it's active within Awful.
 */
extern BOOL SmilieKeyboardIsAwfulAppActive(void);
extern void SmilieKeyboardSetIsAwfulAppActive(BOOL isActive);

extern SmilieList SmilieKeyboardSelectedSmilieList(void);
extern void SmilieKeyboardSetSelectedSmilieList(SmilieList smilieList);

extern float SmilieKeyboardScrollFractionForSmilieList(SmilieList smilieList);
extern void SmilieKeyboardSetScrollFractionForSmilieList(SmilieList smilieList, float scrollFraction);

extern NSURL * SmilieKeyboardSharedContainerURL(void);
