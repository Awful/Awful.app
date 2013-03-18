//
//  ONHost.h
//
//  Copyright 1997-2005, 2012-2013 Omni Development, Inc. All rights reserved.
//
//  Omni Source Code software is available from The Omni Group on their web site at
//  www.omnigroup.com. Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the “Software”), to deal in the Software
//  without restriction, including without limitation the rights to use, copy, modify, merge,
//  publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to
//  whom the Software is furnished to do so, subject to the following conditions: Any original
//  copyright notices and this permission notice shall be included in all copies or substantial
//  portions of the Software. THE SOFTWARE IS PROVIDED “AS IS” WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR
//  A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import <Foundation/Foundation.h>

NSString * IDNEncodedHostname(NSString *aHostname);
NSString * IDNDecodedHostname(NSString *anIDNHostname);
