//
//  AwfulCSSTemplate.h
//  Awful
//
//  Created by Nolan Waite on 12-06-14.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulCSSTemplate : NSObject

- (id)initWithURL:(NSURL *)url error:(NSError **)error;

@property (strong, readonly, nonatomic) NSURL *URL;

@property (strong, readonly, nonatomic) NSString *CSS;

@end


@interface AwfulCSSTemplate (Settings)

+ (AwfulCSSTemplate *)currentTemplate;

+ (AwfulCSSTemplate *)defaultTemplate;

@end
