//  AwfulForumTweaks.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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

- (instancetype)init
{
    if ((self = [super init])) {
        NSURL *themesURL = [[NSBundle mainBundle] URLForResource:@"ForumTweaks" withExtension:@"plist"];
        _tweaks = [NSDictionary dictionaryWithContentsOfURL:themesURL];
    }
    return self;
}

- (AwfulForumTweaks *)tweaksForForumWithID:(NSString *)forumID
{
	NSDictionary *tweaks = _tweaks[forumID];
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

+ (AwfulForumTweaks*)tweaksForForumID:(NSString*)forumID
{
	return [AwfulForumTweaksLoader.sharedLoader tweaksForForumWithID:forumID];
}

+ (id)objectForKeyedSubscript:(NSString *)key
{
	return [self tweaksForForumID:key];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
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

- (NSString *)postButton
{
	return self[@"postButton"];
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
