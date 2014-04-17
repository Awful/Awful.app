//  AwfulFormScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulFormScraper.h"
#import "HTMLNode+CachedSelector.h"
#import "GTMNSString+HTML.h"

@interface AwfulFormScraper ()

@property (copy, nonatomic) NSArray *forms;

@end

@implementation AwfulFormScraper

- (void)scrape
{
    NSMutableArray *forms = [NSMutableArray new];
    for (HTMLElement *formNode in [self.node awful_nodesMatchingCachedSelector:@"form"]) {
        AwfulForm *form = [[AwfulForm alloc] initWithName:formNode[@"name"]];
        for (HTMLElement *threadTagDiv in [formNode awful_nodesMatchingCachedSelector:@"div.posticon"]) {
            HTMLElement *input = [threadTagDiv awful_firstNodeMatchingCachedSelector:@"input"];
            form.threadTagName = input[@"name"];
            HTMLElement *image = [threadTagDiv awful_firstNodeMatchingCachedSelector:@"img"];
            AwfulThreadTag *threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:input[@"value"]
                                                                              threadTagURL:image[@"href"]
                                                                    inManagedObjectContext:self.managedObjectContext];
            NSString *explanation = image[@"alt"];
            if (explanation.length > 0) {
                threadTag.explanation = explanation;
            }
            [form addThreadTag:threadTag];
        }
        
        NSArray *secondaryIconInputs = [formNode awful_nodesMatchingCachedSelector:@"input[type='radio']:not([name='iconid'])"];
        NSArray *secondaryIconImages = [formNode awful_nodesMatchingCachedSelector:@"input[type='radio']:not([name='iconid']) + img"];
        if (secondaryIconInputs.count == secondaryIconImages.count) {
            [secondaryIconInputs enumerateObjectsUsingBlock:^(HTMLElement *input, NSUInteger i, BOOL *stop) {
                HTMLElement *image = secondaryIconImages[i];
                NSString *threadTagID = input[@"value"];
                NSURL *URL = [NSURL URLWithString:image[@"src"]];
                AwfulThreadTag *threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:threadTagID
                                                                                  threadTagURL:URL
                                                                        inManagedObjectContext:self.managedObjectContext];
                [form addSecondaryThreadTag:threadTag];
            }];
            HTMLElement *anyInput = secondaryIconInputs.firstObject;
            form.secondaryThreadTagName = anyInput[@"name"];
        }
        
        for (HTMLElement *input in [formNode awful_nodesMatchingCachedSelector:@"input[type='hidden']"]) {
            [form addHidden:[AwfulFormItem itemWithName:input[@"name"] value:input[@"value"]]];
        }
        for (HTMLElement *input in [formNode awful_nodesMatchingCachedSelector:@"input[type='checkbox']"]) {
            [form addCheckbox:[AwfulFormCheckbox checkboxWithName:input[@"name"] value:input[@"value"] checked:!!input[@"checked"]]];
        }
        for (HTMLElement *input in [formNode awful_nodesMatchingCachedSelector:@"input[type='text']"]) {
            [form addText:[AwfulFormItem itemWithName:input[@"name"] value:input[@"value"]]];
        }
        for (HTMLElement *textarea in [formNode awful_nodesMatchingCachedSelector:@"textarea[name]"]) {
            [form addText:[AwfulFormItem itemWithName:textarea[@"name"]
                                                value:[textarea.innerHTML gtm_stringByUnescapingFromHTML]]];
        }
        for (HTMLElement *input in [formNode awful_nodesMatchingCachedSelector:@"input[type='submit']"]) {
            [form addSubmit:[AwfulFormItem itemWithName:input[@"name"] value:input[@"value"]]];
        }
        for (HTMLElement *file in [formNode awful_nodesMatchingCachedSelector:@"input[type='file']"]) {
            [form addFile:file[@"name"]];
        }
        [forms addObject:form];
    }
    self.forms = forms;
}

@end
