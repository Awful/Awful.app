// The MIT License
// 
// Copyright (c) 2012 Gwendal Roué
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "GRMustacheVariableElement_private.h"
#import "GRMustacheInvocation_private.h"
#import "GRMustacheTemplate_private.h"

@interface GRMustacheVariableElement()
@property (nonatomic, retain) GRMustacheInvocation *invocation;
@property (nonatomic) BOOL raw;
- (id)initWithInvocation:(GRMustacheInvocation *)invocation raw:(BOOL)raw;
- (NSString *)htmlEscape:(NSString *)string;
@end


@implementation GRMustacheVariableElement
@synthesize invocation=_invocation;
@synthesize raw=_raw;

+ (id)variableElementWithInvocation:(GRMustacheInvocation *)invocation raw:(BOOL)raw
{
    return [[[self alloc] initWithInvocation:invocation raw:raw] autorelease];
}

- (void)dealloc
{
    [_invocation release];
    [super dealloc];
}


#pragma mark <GRMustacheRenderingElement>

- (NSString *)renderContext:(GRMustacheContext *)context inRootTemplate:(GRMustacheTemplate *)rootTemplate
{
    // invoke
    
    [_invocation invokeWithContext:context];
    if ([rootTemplate.delegate respondsToSelector:@selector(template:willRenderReturnValueOfInvocation:)]) {
        [rootTemplate.delegate template:rootTemplate willRenderReturnValueOfInvocation:_invocation];
    }
    id value = _invocation.returnValue;
    
    
    // interpret
    
    NSString *result = nil;
    if (value && (value != [NSNull null])) {
        result = [value description];
        if (!_raw) {
            result = [self htmlEscape:result];
        }
    }
    
    
    // finish
    
    if ([rootTemplate.delegate respondsToSelector:@selector(template:didRenderReturnValueOfInvocation:)]) {
        [rootTemplate.delegate template:rootTemplate didRenderReturnValueOfInvocation:_invocation];
    }
    
    if (!result) {
        return @"";
    }
    return result;
}


#pragma mark Private

- (id)initWithInvocation:(GRMustacheInvocation *)invocation raw:(BOOL)raw
{
    self = [self init];
    if (self) {
        self.invocation = invocation;
        self.raw = raw;
    }
    return self;
}

- (NSString *)htmlEscape:(NSString *)string
{
    NSMutableString *result = [NSMutableString stringWithString:string];
    [result replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"'" withString:@"&apos;" options:NSLiteralSearch range:NSMakeRange(0, result.length)];
    return result;
}

@end
