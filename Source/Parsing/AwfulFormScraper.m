//  AwfulFormScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulFormScraper.h"
#import "AwfulForm.h"

@implementation AwfulFormScraper

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error
{
    NSMutableArray *forms = [NSMutableArray new];
    for (HTMLElementNode *formNode in [document nodesMatchingSelector:@"form"]) {
        AwfulForm *form = [[AwfulForm alloc] initWithName:formNode[@"name"]];
        for (HTMLElementNode *threadTagDiv in [formNode nodesMatchingSelector:@"div.posticon"]) {
            HTMLElementNode *input = [threadTagDiv firstNodeMatchingSelector:@"input"];
            form.threadTagName = input[@"name"];
            HTMLElementNode *image = [threadTagDiv firstNodeMatchingSelector:@"img"];
            NSURL *URL = [NSURL URLWithString:image[@"href"] relativeToURL:documentURL];
            AwfulThreadTag *threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:input[@"value"]
                                                                              threadTagURL:URL
                                                                    inManagedObjectContext:managedObjectContext];
            NSString *explanation = image[@"alt"];
            if (explanation.length > 0) {
                threadTag.explanation = explanation;
            }
            [form addThreadTag:threadTag];
        }
        {
            NSArray *secondaryIconInputs = [formNode nodesMatchingSelector:@"input[type='radio']:not([name='iconid'])"];
            NSArray *secondaryIconImages = [formNode nodesMatchingSelector:@"input[type='radio']:not([name='iconid']) + img"];
            if (secondaryIconInputs.count > 0 && secondaryIconInputs.count == secondaryIconImages.count) {
                [secondaryIconInputs enumerateObjectsUsingBlock:^(HTMLElementNode *input, NSUInteger i, BOOL *stop) {
                    HTMLElementNode *image = secondaryIconImages[i];
                    NSString *threadTagID = input[@"value"];
                    NSURL *URL = [NSURL URLWithString:image[@"src"] relativeToURL:documentURL];
                    AwfulThreadTag *threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:threadTagID
                                                                                      threadTagURL:URL
                                                                            inManagedObjectContext:managedObjectContext];
                    [form addSecondaryThreadTag:threadTag];
                }];
            }
        }
        for (HTMLElementNode *input in [formNode nodesMatchingSelector:@"input[type='hidden']"]) {
            [form addHidden:[AwfulFormItem itemWithName:input[@"name"] value:input[@"value"]]];
        }
        for (HTMLElementNode *input in [formNode nodesMatchingSelector:@"input[type='checkbox']"]) {
            [form addCheckbox:[AwfulFormCheckbox checkboxWithName:input[@"name"] value:input[@"value"] checked:!!input[@"checked"]]];
        }
        for (HTMLElementNode *input in [formNode nodesMatchingSelector:@"input[type='text']"]) {
            [form addText:[AwfulFormItem itemWithName:input[@"name"] value:input[@"value"]]];
        }
        for (HTMLElementNode *textarea in [formNode nodesMatchingSelector:@"textarea[name]"]) {
            [form addText:[AwfulFormItem itemWithName:textarea[@"name"] value:textarea.innerHTML]];
        }
        for (HTMLElementNode *input in [formNode nodesMatchingSelector:@"input[type='submit']"]) {
            [form addSubmit:[AwfulFormItem itemWithName:input[@"name"] value:input[@"value"]]];
        }
        for (HTMLElementNode *file in [formNode nodesMatchingSelector:@"input[type='file']"]) {
            [form addFile:file[@"name"]];
        }
        [forms addObject:form];
    }
    [managedObjectContext save:error];
    return forms;
}

@end
