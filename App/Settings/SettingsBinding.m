//  SettingsBinding.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SettingsBinding.h"
@import ObjectiveC.runtime;
#import "Awful-Swift.h"

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
        
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:_settingsKey options:0 context:KVOContext];
    }
    return self;
}

- (void)dealloc
{
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:_settingsKey context:KVOContext];
    for (NSString *key in _overridingSettingsKeys) {
        [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:key context:KVOContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context
{
    if (context != KVOContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([keyPath isEqualToString:self.settingsKey]) {
            [self sendAction];
        }
        
        for (NSString *key in self.overridingSettingsKeys) {
            if ([keyPath isEqualToString:key]) {
                [self sendOverridingAction:key];
            }
        }
    });
}

static void *KVOContext = &KVOContext;

- (void)addOverridingSettingsKeys:(NSSet *)objects
{
    if (!self.overridingSettingsKeys) {
        self.overridingSettingsKeys = [[NSMutableArray alloc] init];
    }
    [self.overridingSettingsKeys addObjectsFromArray:[objects allObjects]];
    
    for (NSString *key in objects) {
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:key options:0 context:KVOContext];
    }
}

- (void)addOverridingSettingsKey:(NSString *)newKey
{
    if (!self.overridingSettingsKeys) {
        self.overridingSettingsKeys = [[NSMutableArray alloc] init];
    }
    [self.overridingSettingsKeys addObject:newKey];
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:newKey options:0 context:KVOContext];
    
}

- (void)sendAction
{
    if (self.target && self.action) {
        id value = [NSUserDefaults.standardUserDefaults objectForKey:self.settingsKey];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.action withObject:value];
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


/// Retrieves a particular setting's info dictionary.
static NSDictionary<NSString *, id> * _Nullable
InfoForSettingWithKeyInSections(NSString *key, NSArray<SettingsSection *> *sections)
{
    for (SettingsSection *section in sections) {
        for (SettingsSectionSetting *setting in section.settings) {
            if ([setting.key isEqualToString:key]) {
                return setting.info;
            }
        }
    }
    return nil;
}


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
        NSAssert(NO, @"Assigning an overriding setting to a setting with no binding.");
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
        
        NSDictionary<NSString *, id> *info = InfoForSettingWithKeyInSections(settingsKey, SettingsSection.mainBundleSections);
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
    [NSUserDefaults.standardUserDefaults setObject:@(self.value) forKey:self.awful_setting];
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
    [NSUserDefaults.standardUserDefaults setBool:self.on forKey:self.awful_setting];
}

- (void)awful_settingDidChange:(NSNumber *)newValue
{
    self.on = newValue.boolValue;
}

- (void)awful_overridingSettingDidChange:(id)overridingSetting
{
    NSString *key = (NSString *)overridingSetting;
    
    if ([self.awful_setting isEqualToString:NSUserDefaults.isDarkModeEnabledKey]) {
        if ([key isEqualToString:NSUserDefaults.automaticallyEnableDarkModeKey]) {
            // If autoDarkTheme is turned on, disable the dark theme switch, since the setting will be toggled automatically
            self.enabled = !NSUserDefaults.standardUserDefaults.automaticallyEnableDarkMode;
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
        NSDictionary *info = InfoForSettingWithKeyInSections(settingsKey, SettingsSection.mainBundleSections);
        if (info[@"Minimum"]) {
            self.minimumValue = [info[@"Minimum"] floatValue];
        }
        if (info[@"Maximum"]) {
            self.maximumValue = [info[@"Maximum"] floatValue];
        }
        
        if (info[@"MinimumImage"]) {
            self.minimumValueImage = [UIImage imageNamed:info[@"MinimumImage"]];
        }
        if (info[@"MaximumImage"]) {
            self.maximumValueImage = [UIImage imageNamed:info[@"MaximumImage"]];
        }
        
        // UISlider needs a kick to display the right value and enablement status
        [self awful_settingDidChange:[NSUserDefaults.standardUserDefaults objectForKey:self.awful_setting]];
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
    [NSUserDefaults.standardUserDefaults setDouble:self.value forKey:self.awful_setting];
}

- (void)awful_settingDidChange:(NSNumber *)newValue
{
    self.value = newValue.floatValue;
}

- (void)awful_overridingSettingDidChange:(id)overridingSetting
{
    // nop
}

@end

@implementation UICollectionView (AwfulSettingsBinding)

- (void)setAwful_setting:(NSString *)settingsKey
{
    [super setAwful_setting:settingsKey];
}

- (void)addAwful_overridingSetting:(NSString *)overridingSettingKey {
    [super addAwful_overridingSetting:overridingSettingKey];
    if (overridingSettingKey) {
        [self awful_overridingSettingDidChange:overridingSettingKey];
    }
}

- (void)awful_valueChanged
{
    //[AwfulSettings sharedSettings][self.awful_setting] = @(self.value);
}

- (void)awful_settingDidChange:(NSNumber *)newValue
{
    //self.value = newValue.doubleValue;
}

- (void)awful_overridingSettingDidChange:(id)overridingSetting
{
    //nop
}

@end
