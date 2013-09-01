//  NSURL+Punycode.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSURL+Punycode.h"
#import "ONHost.h"

@implementation NSURL (Punycode)

+ (instancetype)awful_URLWithString:(NSString *)string
{
    NSURL *firstAttempt = [self URLWithString:string];
    if (firstAttempt) return firstAttempt;
    
    // At this point NSURL has already given up. If we can coax a URL out of the string, that's a
    // bonus. No shame in giving up too.
    
    // We need to parse the host ourselves. Assume a scheme terminated by "://".
    NSScanner *scanner = [NSScanner scannerWithString:string];
    BOOL ok = [scanner scanUpToString:@"://" intoString:NULL];
    ok = [scanner scanString:@"://" intoString:NULL];
    if (!ok) return nil;
    
    // Remember where the host is in the string, for later replacement.
    NSRange rangeOfHost = NSMakeRange([scanner scanLocation], 0);
    
    // The host comes next, up to a : (for port) or / (for path).
    NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@":/"];
    NSString *host;
    ok = [scanner scanUpToCharactersFromSet:set intoString:&host];
    if (ok) {
        rangeOfHost.length = [scanner scanLocation] - rangeOfHost.location;
    } else {
        host = [string substringFromIndex:rangeOfHost.location];
        rangeOfHost.length = [string length] - rangeOfHost.location;
    }
    
    // Punycode-encode the host, then try NSURL once more. If it fails at this point, we give up.
    NSString *encodedHost = IDNEncodedHostname(host);
    string = [string stringByReplacingCharactersInRange:rangeOfHost withString:encodedHost];
    return [NSURL URLWithString:string];
}

- (NSString *)awful_absoluteUnicodeString
{
    NSString *host = [self host];
    NSString *decodedHost = IDNDecodedHostname(host);
    NSString *absoluteString = [self absoluteString];
    if ([host isEqualToString:decodedHost]) return absoluteString;
    NSRange hostRange = [absoluteString rangeOfString:host];
    return [absoluteString stringByReplacingCharactersInRange:hostRange withString:decodedHost];
}

@end
