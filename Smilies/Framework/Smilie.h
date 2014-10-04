//  Smilie.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreGraphics;
#import "SmilieManagedObject.h"
@class SmilieMetadata;

@interface Smilie : SmilieManagedObject

@property (copy, nonatomic) NSData *imageData;
@property (assign, nonatomic) CGSize imageSize;
@property (copy, nonatomic) NSString *imageURL;
@property (copy, nonatomic) NSString *imageUTI;
@property (copy, nonatomic) NSString *section;
@property (copy, nonatomic) NSString *summary;
@property (copy, nonatomic) NSString *text;

@property (readonly, strong, nonatomic) SmilieMetadata *metadata;

@end
