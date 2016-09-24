//  SettingsBinding.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SettingsBinding.h"
#import "AwfulSettings.h"
@import ObjectiveC.runtime;

@interface SettingsBinding : NSObject

@property (copy, nonatomic) NSString *settingsKey;
@property (nonatomic) NSMutableArray *overridingSettingsKeys;
@property (strong, nonatomic) id target;
@property (assign, nonatomic) SEL action;
@property (assign, nonatomic) SEL overridingAction;

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
    
    for (NSString *otherKey in _overridingSettingsKeys) {
        if ([otherKey isEqualToString:key]) {
            [self sendOverridingAction: key];
        }
    }
}

- (void)addOverridingSettingsKeys:(NSSet *)objects
{
    if (!self.overridingSettingsKeys) {
        self.overridingSettingsKeys = [[NSMutableArray alloc] init];
    }
    [self.overridingSettingsKeys addObjectsFromArray:[objects allObjects]];
}

- (void)addOverridingSettingsKey:(NSString *)newKey
{
    if (!self.overridingSettingsKeys) {
        self.overridingSettingsKeys = [[NSMutableArray alloc] init];
    }
    [self.overridingSettingsKeys addObject:newKey];
    
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

- (void)sendOverridingAction:(NSString *)overridingKey
{
    if (self.target && self.overridingAction) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.overridingAction withObject:overridingKey];
        #pragma clang diagnostic pop
    }
}

@end

@implementation UIView (AwfulSettingsBinding)
@dynamic awful_overridingSettings;

- (NSString *)awful_setting
{
    return self.awful_binding.settingsKey;
}

- (NSArray *)awful_overridingSettings
{
    return self.awful_binding.overridingSettingsKeys;
}

- (void)setAwful_setting:(NSString *)settingsKey
{
    SettingsBinding *binding = [[SettingsBinding alloc] initWithSettingsKey:settingsKey];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([self respondsToSelector:@selector(awful_settingDidChange:)]) {
        binding.target = self;
        binding.action = @selector(awful_settingDidChange:);
        [binding sendAction];
    }
    #pragma clang diagnostic pop
    self.awful_binding = binding;
}

- (void)addAwful_overridingSetting:(NSString *)overridingSettingKey
{
    if (self.awful_binding == nil) {
        NSLog(@"WARNING: Assigning an overriding setting to a setting with no binding. Ignoring.");
        return;
    }
    SettingsBinding *binding = self.awful_binding;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([self respondsToSelector:@selector(awful_overridingSettingDidChange:)]) {
        binding.target = self;
        binding.overridingAction = @selector(awful_overridingSettingDidChange:);
        [binding sendAction];
    }
    #pragma clang diagnostic pop

    [self.awful_binding addOverridingSettingsKey:overridingSettingKey];
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

- (void)addAwful_overridingSetting:(NSString *)overridingSettingKey {
    [super addAwful_overridingSetting:overridingSettingKey];
    if (overridingSettingKey) {
        [self awful_overridingSettingDidChange:overridingSettingKey];
    }
}

- (void)awful_overridingSettingDidChange:(id)overridingSetting
{
    // NSString *key = (NSString *)overridingSetting;
    
    // Add checks here for settings combinations that would need an override, when we think of them
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

- (void)addAwful_overridingSetting:(NSString *)overridingSettingKey {
    [super addAwful_overridingSetting:overridingSettingKey];
    if (overridingSettingKey) {
        [self awful_overridingSettingDidChange:overridingSettingKey];
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

- (void)awful_overridingSettingDidChange:(id)overridingSetting
{
    // NSString *key = (NSString *)overridingSetting;
    
    // Add checks here for settings combinations that would need an override, when we think of them
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

- (void)addAwful_overridingSetting:(NSString *)overridingSettingKey {
    [super addAwful_overridingSetting:overridingSettingKey];
    if (overridingSettingKey) {
        [self awful_overridingSettingDidChange:overridingSettingKey];
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

- (void)awful_overridingSettingDidChange:(id)overridingSetting
{
    NSString *key = (NSString *)overridingSetting;
    
    if ([self.awful_setting isEqualToString:AwfulSettingsKeys.darkTheme]) {
        if ([key isEqualToString:AwfulSettingsKeys.autoDarkTheme]) {
            // If autoDarkTheme is turned on, disable the dark theme switch, since the setting will be toggled automatically
            self.enabled = ![AwfulSettings sharedSettings].autoDarkTheme;
        }
    }
}

@end

@implementation UISlider (AwfulSettingsBinding)

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
        
        //UISlider needs a kick to display the right value and enablement status
        [self awful_settingDidChange:[AwfulSettings sharedSettings][self.awful_setting]];
    } else {
        [self removeTarget:self action:@selector(awful_valueChanged) forControlEvents:UIControlEventValueChanged];
    }
}

- (void)addAwful_overridingSetting:(NSString *)overridingSettingKey {
    [super addAwful_overridingSetting:overridingSettingKey];
    if (overridingSettingKey) {
        [self awful_overridingSettingDidChange:overridingSettingKey];
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

- (void)awful_overridingSettingDidChange:(id)overridingSetting
{
    NSString *key = (NSString *)overridingSetting;
    
    if ([self.awful_setting isEqualToString:AwfulSettingsKeys.autoThemeThreshold]) {
        if ([key isEqualToString:AwfulSettingsKeys.autoDarkTheme]) {
            // If autoDarkTheme is turned on, enable the threshold slider, otherwise disable it.
            self.enabled = [AwfulSettings sharedSettings].autoDarkTheme;
        }
    }
}

@end

