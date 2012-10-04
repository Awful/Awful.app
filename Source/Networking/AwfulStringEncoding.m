//
//  AwfulStringEncoding.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-04.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulStringEncoding.h"

NSString * StringFromSomethingAwfulData(NSData *data)
{
    static const NSUInteger encodings[] = {
        // SA's server claims its encoding is ISO-8859-1, which HTML 5 spec says to always parse as
        // Windows-1252, so let's try that first (hint: doesn't always work).
        NSWindowsCP1252StringEncoding,
        
        // As a followup, aim for UTF-8.
        NSUTF8StringEncoding,
        
        // Try ISO-8859-1 anyway.
        NSISOLatin1StringEncoding,
        
        // And as a last-ditch, should-never-fail option, just give something printable back.
        NSNonLossyASCIIStringEncoding
    };
    for (size_t i = 0; i < sizeof(encodings) / sizeof(encodings[0]); i++) {
        NSString *attempt = [[NSString alloc] initWithData:data encoding:encodings[i]];
        if (attempt) return attempt;
    }
    return nil;
}
