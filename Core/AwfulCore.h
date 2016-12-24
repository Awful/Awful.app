//  AwfulCore.h
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

FOUNDATION_EXPORT double AwfulCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char AwfulCoreVersionString[];

// Categories (so Swift can call the methods)
#import <AwfulCore/NSString+Undeprecation.h>

// Model
#import <AwfulCore/AwfulThreadPage.h>

// Scraping
#import <AwfulCore/AwfulForm.h>

// Networking
#import <AwfulCore/AwfulForumsClient.h>
