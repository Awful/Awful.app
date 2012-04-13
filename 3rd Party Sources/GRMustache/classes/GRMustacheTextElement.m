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

#import "GRMustacheTextElement_private.h"


@interface GRMustacheTextElement()
@property (nonatomic, retain) NSString *text;
- (id)initWithString:(NSString *)text;
@end


@implementation GRMustacheTextElement
@synthesize text=_text;

+ (id)textElementWithString:(NSString *)text
{
    return [[[self alloc] initWithString:text] autorelease];
}

- (void)dealloc
{
    [_text release];
    [super dealloc];
}

#pragma mark <GRMustacheRenderingElement>

- (NSString *)renderContext:(GRMustacheContext *)context inRootTemplate:(GRMustacheTemplate *)rootTemplate
{
    return _text;
}

#pragma mark Private

- (id)initWithString:(NSString *)text
{
    self = [self init];
    if (self) {
        self.text = text;
    }
    return self;
}

@end
