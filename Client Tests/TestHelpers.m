//
//  TestHelpers.m
//  Awful
//
//  Created by Nolan Waite on 12-05-08.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "TestHelpers.h"

@interface BundleFinder : NSObject @end
@implementation BundleFinder @end

NSData *BundleData(NSString *filename)
{
    NSBundle *thisBundle = [NSBundle bundleForClass:[BundleFinder class]];
    return [NSData dataWithContentsOfURL:[thisBundle URLForResource:filename
                                                      withExtension:nil]];
}
