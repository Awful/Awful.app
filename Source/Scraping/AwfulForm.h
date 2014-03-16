//  AwfulForm.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
@class AwfulFormItem;
@class AwfulFormCheckbox;

/**
 * An AwfulForm object describes an HTML form.
 */
@interface AwfulForm : NSObject

/**
 * Returns an initialized AwfulForm objects. This is the designated initializer.
 */
- (id)initWithName:(NSString *)name;

/**
 * The name given to the form in markup.
 */
@property (readonly, copy, nonatomic) NSString *name;

/**
 * A dictionary of recommended parameters including hidden inputs, checked boxes, default text values, and the first submit button that may or may not be sufficient for submitting the form.
 */
- (NSMutableDictionary *)recommendedParameters;

/**
 * An array of AwfulThreadTag objects, or nil if none are available.
 */
@property (copy, nonatomic) NSArray *threadTags;

- (void)addThreadTag:(AwfulThreadTag *)threadTag;

/**
 * The item name for the selected thread tag.
 */
@property (copy, nonatomic) NSString *threadTagName;

/**
 * An array of AwfulThreadTag objects, or nil if none are available.
 */
@property (readonly, copy, nonatomic) NSArray *secondaryThreadTags;

- (void)addSecondaryThreadTag:(AwfulThreadTag *)secondaryThreadTag;

/**
 * The item name for the selected secondary thread tag.
 */
@property (copy, nonatomic) NSString *secondaryThreadTagName;

/**
 * An array of AwfulFormItem objects.
 */
@property (readonly, copy, nonatomic) NSArray *hiddens;

- (void)addHidden:(AwfulFormItem *)hidden;

/**
 * An array of AwfulFormCheckbox objects.
 */
@property (readonly, copy, nonatomic) NSArray *checkboxes;

- (void)addCheckbox:(AwfulFormCheckbox *)checkbox;

/**
 * An array of AwfulFormItem objects.
 */
@property (readonly, copy, nonatomic) NSArray *texts;

- (void)addText:(AwfulFormItem *)text;

/**
 * An array of AwfulFormItem objects.
 */
@property (readonly, copy, nonatomic) NSArray *submits;

- (void)addSubmit:(AwfulFormItem *)submit;

/**
 * An array of NSString objects naming each file field.
 */
@property (readonly, copy, nonatomic) NSArray *files;

- (void)addFile:(NSString *)file;

@end

/**
 * An AwfulFormItem is a simple key-value pair from an HTML form.
 */
@interface AwfulFormItem : NSObject

/**
 * Returns an initialized AwfulFormItem. This is the designated initializer.
 */
- (id)initWithName:(NSString *)name value:(NSString *)value;

+ (instancetype)itemWithName:(NSString *)name value:(NSString *)value;

@property (readonly, copy, nonatomic) NSString *name;

@property (readonly, copy, nonatomic) NSString *value;

@end

/**
 * An AwfulFormCheckbox is a simple key-value pair from an HTML form that may be checked by default.
 */
@interface AwfulFormCheckbox : NSObject

/**
 * Returns an initialized AwfulFormCheckbox. This is the designated initializer.
 */
- (id)initWithName:(NSString *)name value:(NSString *)value checked:(BOOL)checked;

+ (instancetype)checkboxWithName:(NSString *)name value:(NSString *)value checked:(BOOL)checked;

@property (readonly, copy, nonatomic) NSString *name;

@property (readonly, copy, nonatomic) NSString *value;

@property (readonly, assign, nonatomic) BOOL checked;

@end
