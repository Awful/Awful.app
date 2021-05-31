//  SmilieWebArchive.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

@interface SmilieWebArchive : NSObject

- (instancetype)initWithURL:(NSURL *)URL;

@property (readonly, strong, nonatomic) NSURL *URL;

@property (readonly, copy, nonatomic) NSString *mainFrameHTML;
@property (readonly, strong, nonatomic) NSURL *mainFrameURL;

- (NSData *)dataForSubresourceWithURL:(NSURL *)subresourceURL;

@end
