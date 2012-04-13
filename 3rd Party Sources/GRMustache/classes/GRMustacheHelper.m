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

#import "GRMustacheHelper_private.h"
#import "GRMustacheSection_private.h"


// =============================================================================
#pragma mark - Private concrete class GRMustacheBlockHelper

#if NS_BLOCKS_AVAILABLE

@interface GRMustacheBlockHelper: GRMustacheHelper {
@private
    NSString *(^_block)(GRMustacheSection* section);
}
- (id)initWithBlock:(NSString *(^)(GRMustacheSection* section))block;
@end

#endif /* if NS_BLOCKS_AVAILABLE */


// =============================================================================
#pragma mark - GRMustacheHelper

@implementation GRMustacheHelper

#if NS_BLOCKS_AVAILABLE

+ (id)helperWithBlock:(NSString *(^)(GRMustacheSection* section))block
{
    return [[[GRMustacheBlockHelper alloc] initWithBlock:block] autorelease];
}

#endif /* if NS_BLOCKS_AVAILABLE */

#pragma mark <GRMustacheHelper>

- (NSString *)renderSection:(GRMustacheSection *)section
{
    NSAssert(NO, @"abstract method");
    return nil;
}

@end


// =============================================================================
#pragma mark - Private concrete class GRMustacheBlockHelper

#if NS_BLOCKS_AVAILABLE

@implementation GRMustacheBlockHelper

- (id)initWithBlock:(NSString *(^)(GRMustacheSection* section))block
{
    self = [self init];
    if (self) {
        _block = [block copy];
    }
    return self;
}


- (void)dealloc
{
    [_block release];
    [super dealloc];
}

#pragma mark <GRMustacheHelper>

- (NSString *)renderSection:(GRMustacheSection *)section
{
    NSString *result = _block(section);
    if (result == nil) {
        return @"";
    }
    return result;
}

@end

#endif /* if NS_BLOCKS_AVAILABLE */
