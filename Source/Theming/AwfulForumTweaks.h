//
//  AwfulForumTweaks.h
//  Awful
//
//  Created by Chris Williams on 12/18/13.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulForumTweaks : NSObject

+ (AwfulForumTweaks*)tweaksForForumId:(NSString*)forumId;


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
