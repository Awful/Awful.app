//  AwfulForumTweaks.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface AwfulForumTweaks : NSObject

+ (instancetype)tweaksForForumID:(NSString *)forumID;

/**
 * Returns a custom post button title
 */
@property (readonly) NSString *postButton;

/**
 * Returns whether text views should autocorrect.
 */
@property (readonly) UITextAutocorrectionType autocorrectionType;

/**
 * Returns whether text views should autocapitalize.
 */
@property (readonly) UITextAutocapitalizationType autocapitalizationType;

/**
 * Returns whether text views should check spelling.
 */
@property (readonly) UITextSpellCheckingType spellCheckingType;

/**
 * Returns whether thread cells should show ratings (Ex. Film dump uses thread tags for ratings)
 */
@property (readonly) BOOL showRatings;

@end
