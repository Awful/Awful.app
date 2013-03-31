//
//  AwfulSettings.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <Foundation/Foundation.h>

@interface AwfulSettings : NSObject

// Singleton instance.
+ (AwfulSettings *)settings;

- (void)registerDefaults;

@property (readonly, strong) NSArray *sections;

- (NSDictionary *)infoForSettingWithKey:(NSString *)key;

@property (assign, nonatomic) BOOL showAvatars;

@property (assign, nonatomic) BOOL showImages;

typedef enum {
    AwfulFirstTabForums,
    AwfulFirstTabFavorites,
    AwfulFirstTabBookmarks,
} AwfulFirstTab;

@property (assign, nonatomic) AwfulFirstTab firstTab;

@property (assign, nonatomic) BOOL highlightOwnQuotes;

@property (assign, nonatomic) BOOL highlightOwnMentions;

@property (assign, nonatomic) BOOL confirmBeforeReplying;

@property (assign, nonatomic) BOOL darkTheme;

@property (copy, nonatomic) NSString *username;

@property (copy, nonatomic) NSString *userID;

@property (assign, nonatomic) BOOL canSendPrivateMessages;

@property (assign, nonatomic) BOOL showThreadTags;

typedef enum {
    AwfulYOSPOSStyleNone,
    AwfulYOSPOSStyleGreen,
    AwfulYOSPOSStyleAmber,
    AwfulYOSPOSStyleMacinyos,
    AwfulYOSPOSStyleWinpos95,
} AwfulYOSPOSStyle;

@property (assign, nonatomic) AwfulYOSPOSStyle yosposStyle;

typedef enum {
    AwfulKeepSidebarOpenNever,
    AwfulKeepSidebarOpenInLandscape,
    AwfulKeepSidebarOpenInPortrait,
    AwfulKeepSidebarOpenAlways,
} AwfulKeepSidebarOpenWhen;

@property (assign, nonatomic) AwfulKeepSidebarOpenWhen keepSidebarOpen;

@property (copy, nonatomic) NSArray *favoriteForums;

@property (nonatomic) NSNumber *fontSize;

@property (assign, nonatomic) BOOL useDevDotForums;

@property (copy, nonatomic) NSString *lastOfferedPasteboardURL;

@property (copy, nonatomic) NSString *lastForcedUserInfoUpdateVersion;

- (id)objectForKeyedSubscript:(id)key;

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key;

@end

// Sent to default center whenever a setting changes. The userInfo dictionary has a value for
// AwfulSettingsDidChangeSettingsKey.
extern NSString * const AwfulSettingsDidChangeNotification;

// A collection (responds to -containsObject:) of settings that changed.
extern NSString * const AwfulSettingsDidChangeSettingsKey;

// Possible values in the AwfulSettingsDidChangeSettingsKey collection, and keys for subscripting.
extern const struct AwfulSettingsKeys {
    __unsafe_unretained NSString *showAvatars;
    __unsafe_unretained NSString *showImages;
    __unsafe_unretained NSString *firstTab;
    __unsafe_unretained NSString *highlightOwnQuotes;
    __unsafe_unretained NSString *highlightOwnMentions;
    __unsafe_unretained NSString *confirmBeforeReplying;
	__unsafe_unretained NSString *darkTheme;
    __unsafe_unretained NSString *username;
    __unsafe_unretained NSString *userID;
    __unsafe_unretained NSString *canSendPrivateMessages;
    __unsafe_unretained NSString *showThreadTags;
    __unsafe_unretained NSString *yosposStyle;
    __unsafe_unretained NSString *keepSidebarOpen;
    __unsafe_unretained NSString *favoriteForums;
    __unsafe_unretained NSString *fontSize;
    __unsafe_unretained NSString *useDevDotForums;
    __unsafe_unretained NSString *lastOfferedPasteboardURL;
    __unsafe_unretained NSString *lastForcedUserInfoUpdateVersion;
} AwfulSettingsKeys;
