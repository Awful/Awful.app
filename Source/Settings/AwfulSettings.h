//
//  AwfulSettings.h
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulSettings : NSObject

// Singleton instance.
+ (AwfulSettings *)settings;

- (void)registerDefaults;

@property (readonly, strong) NSArray *sections;

@property (assign, nonatomic) BOOL showAvatars;

@property (assign, nonatomic) BOOL showImages;

typedef enum
{
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

@end

// Sent to default center whenever a setting changes. The userInfo dictionary has a value for
// AwfulSettingsDidChangeSettingsKey.
extern NSString * const AwfulSettingsDidChangeNotification;

// A collection (responds to -containsObject:) of settings that changed.
extern NSString * const AwfulSettingsDidChangeSettingsKey;

// Possible values in the AwfulSettingsDidChangeSettingsKey collection.
extern const struct AwfulSettingsKeys {
	__unsafe_unretained NSString *darkTheme;
} AwfulSettingsKeys;
