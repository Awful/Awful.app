//  SmilieFetchedDataSource.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
#import <Smilies/SmilieKeyboardView.h>
@class Smilie;
@class SmilieDataStore;

@interface SmilieFetchedDataSource : NSObject <SmilieKeyboardDataSource>

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore;

@property (readonly, strong, nonatomic) SmilieDataStore *dataStore;

- (Smilie *)smilieAtIndexPath:(NSIndexPath *)indexPath;

@end
