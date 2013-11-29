//  AwfulForm.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForm.h"

@implementation AwfulForm
{
    NSMutableArray *_threadTags;
    NSMutableArray *_secondaryThreadTags;
    NSMutableArray *_hiddens;
    NSMutableArray *_checkboxes;
    NSMutableArray *_texts;
    NSMutableArray *_submits;
    NSMutableArray *_files;
}

- (id)initWithName:(NSString *)name
{
    self = [super init];
    if (!self) return nil;
    _name = [name copy];
    return self;
}

- (NSMutableDictionary *)recommendedParameters
{
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    for (AwfulFormItem *item in _hiddens) {
        parameters[item.name] = item.value;
    }
    for (AwfulFormCheckbox *checkbox in _checkboxes) {
        if (checkbox.checked) {
            parameters[checkbox.name] = checkbox.value;
        }
    }
    for (AwfulFormItem *item in _texts) {
        if (item.value.length > 0) {
            parameters[item.name] = item.value;
        }
    }
    for (AwfulFormItem *item in _submits) {
        if (item.value.length > 0) {
            parameters[item.name] = item.value;
            break;
        }
    }
    return parameters;
}

- (NSArray *)threadTags
{
    return [_threadTags copy];
}

- (void)addThreadTag:(AwfulThreadTag *)threadTag
{
    if (!_threadTags) _threadTags = [NSMutableArray new];
    [_threadTags addObject:threadTag];
}

- (NSArray *)secondaryThreadTags
{
    return [_secondaryThreadTags copy];
}

- (void)addSecondaryThreadTag:(AwfulThreadTag *)secondaryThreadTag
{
    if (!_secondaryThreadTags) _secondaryThreadTags = [NSMutableArray new];
    [_secondaryThreadTags addObject:secondaryThreadTag];
}

- (NSArray *)hiddens
{
    return [_hiddens copy];
}

- (void)addHidden:(AwfulFormItem *)hidden
{
    if (!_hiddens) _hiddens = [NSMutableArray new];
    [_hiddens addObject:hidden];
}

- (NSArray *)checkboxes
{
    return [_checkboxes copy];
}

- (void)addCheckbox:(AwfulFormCheckbox *)checkbox
{
    if (!_checkboxes) _checkboxes = [NSMutableArray new];
    [_checkboxes addObject:checkbox];
}

- (NSArray *)texts
{
    return [_texts copy];
}

- (void)addText:(AwfulFormItem *)text
{
    if (!_texts) _texts = [NSMutableArray new];
    [_texts addObject:text];
}

- (NSArray *)submits
{
    return [_submits copy];
}

- (void)addSubmit:(AwfulFormItem *)submit
{
    if (!_submits) _submits = [NSMutableArray new];
    [_submits addObject:submit];
}

- (NSArray *)files
{
    return [_files copy];
}

- (void)addFile:(NSString *)file
{
    if (!_files) _files = [NSMutableArray new];
    [_files addObject:[file copy]];
}

@end

@implementation AwfulFormItem

- (id)initWithName:(NSString *)name value:(NSString *)value
{
    self = [super init];
    if (!self) return nil;
    _name = [name copy];
    _value = [value copy];
    return self;
}

+ (instancetype)itemWithName:(NSString *)name value:(NSString *)value
{
    return [[self alloc] initWithName:name value:value];
}

@end

@implementation AwfulFormCheckbox

- (id)initWithName:(NSString *)name value:(NSString *)value checked:(BOOL)checked
{
    self = [super init];
    if (!self) return nil;
    _name = [name copy];
    _value = [value copy];
    _checked = checked;
    return self;
}

+ (instancetype)checkboxWithName:(NSString *)name value:(NSString *)value checked:(BOOL)checked
{
    return [[self alloc] initWithName:name value:value checked:checked];
}

@end
