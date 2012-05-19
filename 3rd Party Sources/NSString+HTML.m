//
//  NSString+HTML.m
//  MWFeedParser
//
//  Copyright (c) 2010 Michael Waterfall
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  1. The above copyright notice and this permission notice shall be included
//     in all copies or substantial portions of the Software.
//  
//  2. This Software cannot be used to archive or collect data such as (but not
//     limited to) that of events, news, experiences and activities, for the 
//     purpose of any concept relating to diary/journal keeping.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "NSString+HTML.h"

@implementation NSString (HTML)

- (NSString *)stringByEscapingUnicode
{
	if (!self.length) {
		return self;
	}
	
	NSMutableString *finalString = [NSMutableString string];
	NSMutableData *data2 = [NSMutableData dataWithCapacity:sizeof(unichar) * self.length];
	
	const unichar *buffer = CFStringGetCharactersPtr((__bridge CFStringRef)self);
	if (!buffer) {
		// We want this buffer to be autoreleased.
		NSMutableData *data = [NSMutableData dataWithLength:self.length * sizeof(UniChar)];
		if (!data) {
			NSLog(@"couldn't alloc buffer");
			return nil;
		}
		[self getCharacters:[data mutableBytes]];
		buffer = [data bytes];
	}
	
	if (!buffer || !data2) {
		NSLog(@"Unable to allocate buffer or data2");
		return nil;
	}
	
	unichar *buffer2 = (unichar *)[data2 mutableBytes];
	
	NSUInteger buffer2Length = 0;
	
	for (NSUInteger i = 0; i < self.length; ++i) {
		if (buffer[i] > 127) {
			if (buffer2Length) {
				CFStringAppendCharacters((__bridge CFMutableStringRef)finalString, 
										 buffer2, 
										 buffer2Length);
				buffer2Length = 0;
			}
            [finalString appendFormat:@"&#%d;", buffer[i]];
		} else {
			buffer2[buffer2Length] = buffer[i];
			buffer2Length += 1;
		}
	}
	if (buffer2Length) {
		CFStringAppendCharacters((__bridge CFMutableStringRef)finalString, 
								 buffer2, 
								 buffer2Length);
	}
	return finalString;
}

@end
