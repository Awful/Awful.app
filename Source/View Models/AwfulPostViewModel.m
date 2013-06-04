//
//  AwfulPostViewModel.m
//  Awful
//
//  Created by Nolan Waite on 2013-06-04.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPostViewModel.h"
#import "AwfulDateFormatters.h"

@interface AwfulPostViewModel ()

@property (nonatomic) AwfulPost *post;

@end


@implementation AwfulPostViewModel

+ (id)newWithPost:(AwfulPost *)post
{
    AwfulPostViewModel *viewModel = [self new];
    viewModel.post = post;
    return viewModel;
}

- (BOOL)authorIsOP
{
    return [self.post.author isEqual:self.post.thread.author];
}

- (NSDateFormatter *)postDateFormat
{
    return AwfulDateFormatters.formatters.postDateFormatter;
}

- (NSDateFormatter *)regDateFormat
{
    return AwfulDateFormatters.formatters.regDateFormatter;
}

- (NSDateFormatter *)editDateFormat
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    // Jan 2, 2003 around 4:05
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    formatter.dateFormat = @"MMM d, yyy 'around' HH:mm";
    return formatter;
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.post valueForKey:key];
}

@end
