//  AwfulForm.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForm.h"

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
    NSArray *_threadTagElements;
    NSMutableArray *_secondaryThreadTagDictionaries;
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
        _threadTagElements = [self.element nodesMatchingSelector:@"div.posticon"];
        HTMLElement *anyThreadTagElement = _threadTagElements.firstObject;
        self.selectedThreadTagKey = [anyThreadTagElement firstNodeMatchingSelector:@"input"][@"name"];
    }}
    
    {{
        _secondaryThreadTagDictionaries = [NSMutableArray new];
        NSArray *inputs = [self.element nodesMatchingSelector:@"input[type='radio']:not([name='iconid'])"];
        NSArray *images = [self.element nodesMatchingSelector:@"input[type='radio']:not([name='iconid']) + img"];
        if (inputs.count == images.count) {
            [inputs enumerateObjectsUsingBlock:^(HTMLElement *input, NSUInteger i, BOOL *stop) {
                NSString *threadTagID = input[@"value"];
                HTMLElement *image = images[i];
                NSURL *imageURL = [NSURL URLWithString:image[@"src"]];
                if (threadTagID && imageURL) {
                    [_secondaryThreadTagDictionaries addObject:@{ @"threadTagID": threadTagID,
                                                                  @"imageURL": imageURL }];
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
    
    NSMutableArray *existingIDs = [NSMutableArray new];
    for (HTMLElement *div in _threadTagElements) {
        HTMLElement *input = [div firstNodeMatchingSelector:@"input"];
        NSString *threadTagID = input[@"value"];
        if (threadTagID.length > 0) {
            [existingIDs addObject:threadTagID];
        }
    }
    [existingIDs addObjectsFromArray:[_secondaryThreadTagDictionaries valueForKey:@"threadTagID"]];
    NSDictionary *existingThreadTags = [AwfulThreadTag dictionaryOfAllInManagedObjectContext:managedObjectContext
                                                                       keyedByAttributeNamed:@"threadTagID"
                                                                     matchingPredicateFormat:@"threadTagID IN %@", existingIDs];
    
    NSMutableArray *threadTags = [NSMutableArray new];
    for (HTMLElement *div in _threadTagElements) {
        HTMLElement *input = [div firstNodeMatchingSelector:@"input"];
        NSString *threadTagID = input[@"value"];
        HTMLElement *image = [div firstNodeMatchingSelector:@"img"];
        NSURL *URL = [NSURL URLWithString:image[@"src"]];
        if (threadTagID.length == 0 || !URL) continue;
        AwfulThreadTag *threadTag = existingThreadTags[threadTagID];
        if (threadTag) {
            [threadTag setURL:URL];
        } else {
            threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:threadTagID
                                                              threadTagURL:URL
                                                    inManagedObjectContext:managedObjectContext];
        }
        threadTag.explanation = image[@"alt"];
        [threadTags addObject:threadTag];
    }
    self.threadTags = threadTags;
    
    NSMutableArray *secondaryThreadTags = [NSMutableArray new];
    for (NSDictionary *info in _secondaryThreadTagDictionaries) {
        AwfulThreadTag *threadTag = existingThreadTags[info[@"threadTagID"]];
        if (threadTag) {
            [threadTag setURL:info[@"imageURL"]];
        } else {
            threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:info[@"threadTagID"]
                                                              threadTagURL:info[@"imageURL"]
                                                    inManagedObjectContext:managedObjectContext];
        }
        [secondaryThreadTags addObject:threadTag];
    }
    self.secondaryThreadTags = secondaryThreadTags;
}

@end
