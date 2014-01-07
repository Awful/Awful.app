//  AwfulPostViewModel.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
    return AwfulDateFormatters.postDateFormatter;
}

- (NSDateFormatter *)regDateFormat
{
    return AwfulDateFormatters.regDateFormatter;
}

- (NSDateFormatter *)editDateFormat
{
	static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
		
		NSDateFormatter *dateFormatter = [NSDateFormatter new];
		dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        dateFormatter.timeStyle = NSDateFormatterNoStyle;
		
		NSDateFormatter *timeFormatter = [NSDateFormatter new];
		timeFormatter.dateStyle = NSDateFormatterNoStyle;
        timeFormatter.timeStyle = kCFDateFormatterShortStyle;

		
		// Jan 2, 2003 around 4:05
		NSString *aroundFormatString = [NSString stringWithFormat:@"%@ 'around' %@", dateFormatter.dateFormat, timeFormatter.dateFormat];
		
		formatter.dateFormat = aroundFormatString;
    });
    return formatter;
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.post valueForKey:key];
}

@end
