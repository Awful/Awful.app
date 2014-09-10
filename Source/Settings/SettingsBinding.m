//  SettingsBinding.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SettingsBinding.h"
#import "AwfulSettings.h"
#import <objc/runtime.h>

@interface SettingsBinding : NSObject

@property (copy, nonatomic) NSString *settingsKey;
@property (strong, nonatomic) id target;
@property (assign, nonatomic) SEL action;

@end

@interface UIView (AwfulSettingsBinding) <SettingsBindable>

@property (strong, nonatomic) SettingsBinding *awful_binding;

@end

@implementation SettingsBinding

- (instancetype)initWithSettingsKey:(NSString *)settingsKey
{
    if ((self = [super init])) {
        _settingsKey = [settingsKey copy];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:AwfulSettingsDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)settingsDidChange:(NSNotification *)notification
{
    NSString *key = notification.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([key isEqualToString:self.settingsKey]) {
        [self sendAction];
    }
}

- (void)sendAction
{
    if (self.target && self.action) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.action withObject:[AwfulSettings sharedSettings][self.settingsKey]];
        #pragma clang diagnostic pop
    }
}

@end

@implementation UIView (AwfulSettingsBinding)

- (NSString *)awful_setting
{
    return self.awful_binding.settingsKey;
}

- (void)setAwful_setting:(NSString *)settingsKey
{
    SettingsBinding *binding = [[SettingsBinding alloc] initWithSettingsKey:settingsKey];
    if ([self respondsToSelector:@selector(awful_settingDidChange:)]) {
        binding.target = self;
        binding.action = @selector(awful_settingDidChange:);
        [binding sendAction];
    }
    self.awful_binding = binding;
}

- (SettingsBinding *)awful_binding
{
    return objc_getAssociatedObject(self, AssociatedBinding);
}

- (void)setAwful_binding:(SettingsBinding *)binding
{
    objc_setAssociatedObject(self, AssociatedBinding, binding, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

const static void * AssociatedBinding = &AssociatedBinding;

@end

@implementation UILabel (AwfulSettingsBinding)

- (void)awful_settingDidChange:(id)newValue
{
    NSString *formatString = self.awful_settingFormatString;
    self.text = [NSString stringWithFormat:formatString ?: @"%@", newValue];
}

- (NSString *)awful_settingFormatString
{
    return objc_getAssociatedObject(self, AssociatedFormatString);
}

- (void)setAwful_settingFormatString:(NSString *)formatString
{
    objc_setAssociatedObject(self, AssociatedFormatString, formatString, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self.awful_binding sendAction];
}

const static void * AssociatedFormatString = &AssociatedFormatString;

@end

@implementation UIStepper (AwfulSettingsBinding)

- (void)setAwful_setting:(NSString *)settingsKey
{
    [super setAwful_setting:settingsKey];
    if (settingsKey) {
        if (![[self actionsForTarget:self forControlEvent:UIControlEventValueChanged] containsObject:NSStringFromSelector(@selector(awful_valueChanged))]) {
            [self addTarget:self action:@selector(awful_valueChanged) forControlEvents:UIControlEventValueChanged];
        }
        
        NSDictionary *info = [[AwfulSettings sharedSettings] infoForSettingWithKey:settingsKey];
        if (info[@"Minimum"]) {
            self.minimumValue = [info[@"Minimum"] doubleValue];
        }
        if (info[@"Maximum"]) {
            self.maximumValue = [info[@"Maximum"] doubleValue];
        }
        if (info[@"Increment"]) {
            self.stepValue = [info[@"Increment"] doubleValue];
        }
    } else {
        [self removeTarget:self action:@selector(awful_valueChanged) forControlEvents:UIControlEventValueChanged];
    }
}

- (void)awful_valueChanged
{
    [AwfulSettings sharedSettings][self.awful_setting] = @(self.value);
}

- (void)awful_settingDidChange:(NSNumber *)newValue
{
    self.value = newValue.doubleValue;
}

@end

@implementation UISwitch (AwfulSettingsBinding)

- (void)setAwful_setting:(NSString *)settingsKey
{
    [super setAwful_setting:settingsKey];
    if (settingsKey) {
        if (![[self actionsForTarget:self forControlEvent:UIControlEventValueChanged] containsObject:NSStringFromSelector(@selector(awful_valueChanged))]) {
            [self addTarget:self action:@selector(awful_valueChanged) forControlEvents:UIControlEventValueChanged];
        }
    } else {
        [self removeTarget:self action:@selector(awful_valueChanged) forControlEvents:UIControlEventValueChanged];
    }
}

- (void)awful_valueChanged
{
    [AwfulSettings sharedSettings][self.awful_setting] = @(self.on);
}

- (void)awful_settingDidChange:(NSNumber *)newValue
{
    self.on = newValue.boolValue;
}

@end
