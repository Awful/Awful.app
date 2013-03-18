//
//  NSURL+Punycode.h
//  Awful
//
//  Created by Nolan Waite on 2013-03-18.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (Punycode)

// Replacement for +[NSURL URLWithString:] that handles punycode-encoded hostnames.
+ (instancetype)awful_URLWithString:(NSString *)string;

// Replacement for -[NSURL absoluteString] that decodes punycode-encoded hostnames.
- (NSString *)awful_absoluteUnicodeString;

@end
