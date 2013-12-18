//
//  AwfulForumTweaks.m
//  Awful
//
//  Created by Chris Williams on 12/18/13.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulForumTweaks.h"

@interface AwfulForumTweaks ()
{
	NSDictionary *_dictionary;
}

+ (instancetype)defaultTweaks;

- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

@end

@interface AwfulForumTweaksLoader : NSObject
{
	NSDictionary *_tweaks;
}

+ (instancetype)sharedLoader;

@end

@implementation AwfulForumTweaksLoader

+ (instancetype)sharedLoader
{
    static AwfulForumTweaksLoader *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    NSURL *themesURL = [[NSBundle mainBundle] URLForResource:@"ForumTweaks" withExtension:@"plist"];
    _tweaks = [NSDictionary dictionaryWithContentsOfURL:themesURL];
    return self;
}

- (AwfulForumTweaks *)tweaksForForumWithID:(NSString *)forumID
{
	NSDictionary *tweaks = _tweaks[forumID];
	
	if (!tweaks) {
		
	}
	
    return [[AwfulForumTweaks alloc] initWithDictionary:tweaks];
}

@end

@implementation AwfulForumTweaks

+(instancetype)defaultTweaks
{
	static AwfulForumTweaks *defaultTweaks;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		defaultTweaks = [AwfulForumTweaks new];
	});
	return defaultTweaks;
}

+ (AwfulForumTweaks*)tweaksForForumId:(NSString*)forumId
{
	return [AwfulForumTweaksLoader.sharedLoader tweaksForForumWithID:forumId];
}

+ (id)objectForKeyedSubscript:(NSString *)key
{
	return [self tweaksForForumId:key];
}

-(instancetype)initWithDictionary:(NSDictionary *)dictionary
{
	if (!(self = [super init])) return nil;
	
	_dictionary = dictionary;
	
    return self;
}

- (id)objectForKey:(id)key
{
    return _dictionary[key];
}

- (id)objectForKeyedSubscript:(NSString *)key
{
	return [self objectForKey:key];
}

- (UITextAutocorrectionType)autocorrectionType
{
    id value = self[@"autocorrection"];
    if (value) {
        return [value boolValue] ? UITextAutocorrectionTypeYes : UITextAutocorrectionTypeNo;
    } else {
        return UITextAutocorrectionTypeDefault;
    }
}

- (UITextAutocapitalizationType)autocapitalizationType
{
    id value = self[@"autocapitalization"];
    if (value && ![value boolValue]) {
        return UITextAutocapitalizationTypeNone;
    } else {
        return UITextAutocapitalizationTypeSentences;
    }
}

- (UITextSpellCheckingType)spellCheckingType
{
    id value = self[@"checkSpelling"];
    if (value) {
        return [value boolValue] ? UITextSpellCheckingTypeYes : UITextSpellCheckingTypeNo;
    } else {
        return UITextSpellCheckingTypeDefault;
    }
}

- (BOOL)showRatings
{
	id value = self[@"showRatings"];
    return value && [value boolValue];
}


@end
