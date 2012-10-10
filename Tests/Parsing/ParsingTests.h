//
//  ParsingTests.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "AwfulDataStack.h"

@interface ParsingTests : SenTestCase

@property (readonly, copy, nonatomic) NSData *fixture;

+ (NSString *)fixtureFilename;

@end


@interface CoreDataParsingTests : ParsingTests

@property (readonly, strong, nonatomic) AwfulDataStack *dataStack;

@end
