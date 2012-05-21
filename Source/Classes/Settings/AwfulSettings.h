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

@property (assign, nonatomic) NSInteger loadReadPosts;

typedef enum
{
    AwfulFirstTabForums,
    AwfulFirstTabFavorites,
    AwfulFirstTabBookmarks,
} AwfulFirstTab;

@property (assign, nonatomic) AwfulFirstTab firstTab;

@property (assign, nonatomic) BOOL highlightOwnQuotes;

@property (assign, nonatomic) BOOL highlightOwnMentions;

@property (assign, nonatomic) BOOL darkTheme;

@end
