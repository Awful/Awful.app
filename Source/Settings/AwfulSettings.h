//  AwfulSettings.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

@interface AwfulSettings : NSObject

// Singleton instance.
+ (AwfulSettings *)settings;

- (void)registerDefaults;

@property (readonly, strong) NSArray *sections;

- (NSDictionary *)infoForSettingWithKey:(NSString *)key;

@property (assign, nonatomic) BOOL showAvatars;

@property (assign, nonatomic) BOOL showImages;

typedef NS_ENUM(NSInteger, AwfulFirstTab) {
    AwfulFirstTabForums,
    AwfulFirstTabPrivateMessages,
    AwfulFirstTabBookmarks,
};

@property (assign, nonatomic) AwfulFirstTab firstTab;

@property (assign, nonatomic) BOOL highlightOwnQuotes;

@property (assign, nonatomic) BOOL highlightOwnMentions;

@property (assign, nonatomic) BOOL confirmNewPosts;

@property (assign, nonatomic) BOOL darkTheme;

@property (copy, nonatomic) NSString *username;

@property (copy, nonatomic) NSString *userID;

@property (nonatomic, readonly) NSString *pocketUsername;

@property (assign, nonatomic) BOOL canSendPrivateMessages;

@property (assign, nonatomic) BOOL showThreadTags;

typedef NS_ENUM(NSInteger, AwfulYOSPOSStyle) {
    AwfulYOSPOSStyleNone,
    AwfulYOSPOSStyleGreen,
    AwfulYOSPOSStyleAmber,
    AwfulYOSPOSStyleMacinyos,
    AwfulYOSPOSStyleWinpos95,
};

@property (assign, nonatomic) AwfulYOSPOSStyle yosposStyle;

typedef NS_ENUM(NSInteger, AwfulFYADStyle) {
    AwfulFYADStyleNone,
    AwfulFYADStylePink,
};

@property (assign, nonatomic) AwfulFYADStyle fyadStyle;

typedef NS_ENUM(NSInteger, AwfulGasChamberStyle) {
    AwfulGasChamberStyleNone,
    AwfulGasChamberStyleSickly,
};

@property (assign, nonatomic) AwfulGasChamberStyle gasChamberStyle;

@property (copy, nonatomic) NSArray *favoriteForums;

@property (nonatomic) NSNumber *fontSize;

@property (copy, nonatomic) NSString *lastOfferedPasteboardURL;

@property (copy, nonatomic) NSString *lastForcedUserInfoUpdateVersion;

@property (copy, nonatomic) NSString *customBaseURL;

@property (copy, nonatomic) NSString *instapaperUsername;

@property (copy, nonatomic) NSString *instapaperPassword;

- (id)objectForKeyedSubscript:(id)key;

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key;

// Clears all settings.
- (void)reset;

@end

// Sent to default center whenever a setting changes. The userInfo dictionary has a value for
// AwfulSettingsDidChangeSettingsKey.
extern NSString * const AwfulSettingsDidChangeNotification;

// An NSArray of settings keys (see AwfulSettingsKeys) that changed.
extern NSString * const AwfulSettingsDidChangeSettingsKey;

// Possible values in the AwfulSettingsDidChangeSettingsKey collection, and keys for subscripting.
extern const struct AwfulSettingsKeys {
    __unsafe_unretained NSString *showAvatars;
    __unsafe_unretained NSString *showImages;
    __unsafe_unretained NSString *firstTab;
    __unsafe_unretained NSString *highlightOwnQuotes;
    __unsafe_unretained NSString *highlightOwnMentions;
    __unsafe_unretained NSString *confirmNewPosts;
    __unsafe_unretained NSString *darkTheme;
    __unsafe_unretained NSString *username;
    __unsafe_unretained NSString *userID;
    __unsafe_unretained NSString *canSendPrivateMessages;
    __unsafe_unretained NSString *showThreadTags;
    __unsafe_unretained NSString *yosposStyle;
    __unsafe_unretained NSString *fyadStyle;
    __unsafe_unretained NSString *gasChamberStyle;
    __unsafe_unretained NSString *favoriteForums;
    __unsafe_unretained NSString *fontSize;
    __unsafe_unretained NSString *lastOfferedPasteboardURL;
    __unsafe_unretained NSString *lastForcedUserInfoUpdateVersion;
    __unsafe_unretained NSString *customBaseURL;
    __unsafe_unretained NSString *instapaperUsername;
} AwfulSettingsKeys;
