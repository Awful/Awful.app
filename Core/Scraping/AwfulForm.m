//  AwfulForm.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForm.h"
#import <AwfulCore/AwfulCore-Swift.h>

@interface AwfulForm ()

@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *HTTPMethod;
@property (strong, nonatomic) NSURL *submissionURL;

@property (copy, nonatomic) NSString *selectedThreadTagKey;
@property (copy, nonatomic) NSArray *threadTags;
@property (copy, nonatomic) NSString *selectedSecondaryThreadTagKey;
@property (copy, nonatomic) NSArray *secondaryThreadTags;

@end

@implementation AwfulForm
{
    BOOL _didScrape;
    NSMutableArray *_requiredInputElements;
    NSArray *_textareaElements;
    NSMutableArray *_optionalInputElements;
    NSMutableArray *_threadTagKeys;
    NSMutableArray *_secondaryThreadTagKeys;
}

- (id)initWithElement:(HTMLElement *)element
{
    if ([element.tagName caseInsensitiveCompare:@"form"] != NSOrderedSame) return nil;
    
    if ((self = [super init])) {
        _element = element;
    }
    return self;
}

- (NSString *)name
{
    [self scrapeIfNecessary];
    return _name;
}

- (NSString *)HTTPMethod
{
    [self scrapeIfNecessary];
    return _HTTPMethod;
}

- (NSURL *)submissionURL
{
    [self scrapeIfNecessary];
    return _submissionURL;
}

- (NSString *)selectedThreadTagKey
{
    [self scrapeIfNecessary];
    return _selectedThreadTagKey;
}

- (NSString *)selectedSecondaryThreadTagKey
{
    [self scrapeIfNecessary];
    return _selectedSecondaryThreadTagKey;
}

- (NSMutableDictionary *)recommendedParameters
{
    [self scrapeIfNecessary];
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    for (HTMLElement *input in _requiredInputElements) {
        NSString *name = input[@"name"];
        NSString *value = input[@"value"] ?: @"";
        if (name) parameters[name] = value;
    }
    for (HTMLElement *textarea in _textareaElements) {
        NSString *name = textarea[@"name"];
        NSString *value = [textarea.textContent html_stringByUnescapingHTML];
        parameters[name] = value;
    }
    return parameters;
}

- (NSDictionary *)allParameters
{
    [self scrapeIfNecessary];
    NSMutableDictionary *parameters = [self recommendedParameters];
    for (HTMLElement *input in _optionalInputElements) {
        NSString *name = input[@"name"];
        NSString *value = input[@"value"] ?: @"";
        if (name) parameters[name] = value;
    }
    if (self.selectedThreadTagKey) {
        parameters[self.selectedThreadTagKey] = @"";
    }
    if (self.selectedSecondaryThreadTagKey) {
        parameters[self.selectedSecondaryThreadTagKey] = @"";
    }
    return parameters;
}

- (void)scrapeIfNecessary
{
    if (_didScrape) return;
    
    self.name = self.element[@"name"];
    self.HTTPMethod = [self.element[@"action"] uppercaseString];
    self.submissionURL = [NSURL URLWithString:self.element[@"action"]];
    
    {{
        _requiredInputElements = [NSMutableArray new];
        _optionalInputElements = [NSMutableArray new];
        for (HTMLElement *input in [self.element nodesMatchingSelector:@"input"]) {
            NSString *type = [input[@"type"] lowercaseString];
            if ([type isEqualToString:@"hidden"]) {
                [_requiredInputElements addObject:input];
            } else if ([type isEqualToString:@"checkbox"] || [type isEqualToString:@"radio"]) {
                if (input[@"checked"]) {
                    [_requiredInputElements addObject:input];
                } else {
                    [_optionalInputElements addObject:input];
                }
            } else if ([type isEqualToString:@"submit"]) {
                [_requiredInputElements addObject:input];
            } else if ([type isEqualToString:@"text"] || !type) {
                [_requiredInputElements addObject:input];
            }
        }
    }}
    
    {{
        _textareaElements = [self.element nodesMatchingSelector:@"textarea[name]"];
    }}
    
    {{
        _threadTagKeys = [NSMutableArray new];
        NSArray *tagElements = [self.element nodesMatchingSelector:@"div.posticon"];
        for (HTMLElement *div in tagElements) {
            HTMLElement *input = [div firstNodeMatchingSelector:@"input"];
            NSString *threadTagID = input[@"value"];
            HTMLElement *image = [div firstNodeMatchingSelector:@"img"];
            NSURL *imageURL = [NSURL URLWithString:image[@"src"]];
            if (threadTagID.length > 0 && imageURL) {
                [_threadTagKeys addObject:[[ThreadTagKey alloc] initWithImageURL:imageURL threadTagID:threadTagID]];
            }
        }
        
        HTMLElement *anyThreadTagElement = tagElements.firstObject;
        self.selectedThreadTagKey = [anyThreadTagElement firstNodeMatchingSelector:@"input"][@"name"];
    }}
    
    {{
        _secondaryThreadTagKeys = [NSMutableArray new];
        NSArray *inputs = [self.element nodesMatchingSelector:@"input[type='radio']:not([name='iconid'])"];
        NSArray *images = [self.element nodesMatchingSelector:@"input[type='radio']:not([name='iconid']) + img"];
        if (inputs.count == images.count) {
            [inputs enumerateObjectsUsingBlock:^(HTMLElement *input, NSUInteger i, BOOL *stop) {
                NSString *threadTagID = input[@"value"];
                HTMLElement *image = images[i];
                NSURL *imageURL = [NSURL URLWithString:image[@"src"]];
                if (threadTagID.length > 0 && imageURL) {
                    [_secondaryThreadTagKeys addObject:[[ThreadTagKey alloc] initWithImageURL:imageURL threadTagID:threadTagID]];
                }
            }];
            HTMLElement *input = inputs.firstObject;
            self.selectedSecondaryThreadTagKey = input[@"name"];
        }
    }}
    
    _didScrape = YES;
}

- (void)scrapeThreadTagsIntoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSParameterAssert(managedObjectContext);
    
    [self scrapeIfNecessary];
    
    if (_threadTagKeys.count > 0) {
        self.threadTags = [ThreadTag objectsForKeys:_threadTagKeys inManagedObjectContext:managedObjectContext];
    }
    if (_secondaryThreadTagKeys.count > 0) {
        self.secondaryThreadTags = [ThreadTag objectsForKeys:_secondaryThreadTagKeys inManagedObjectContext:managedObjectContext];
    }
}

@end
