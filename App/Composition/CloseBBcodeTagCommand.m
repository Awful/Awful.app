//  CloseBBcodeTagCommand.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "CloseBBcodeTagCommand.h"

@interface CloseBBcodeTagCommand ()

@property (assign, nonatomic) BOOL enabled;

@end

@implementation CloseBBcodeTagCommand

- (instancetype)initWithTextView:(UITextView *)textView
{
    if ((self = [super init])) {
        _textView = textView;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:UITextViewTextDidChangeNotification object:textView];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)textDidChange:(NSNotification *)note
{
    NSString *textContent = [self.textView.text substringToIndex:self.textView.selectedRange.location];
    self.enabled = !![self getCurrentlyOpenTag:textContent];
}

- (void)execute
{
    NSString *textContent = [self.textView.text substringToIndex:self.textView.selectedRange.location];
    
    if ([self hasOpenCodeTag:textContent]) {
        [self.textView insertText:@"[/code]"];
        return;
    }
    
    NSString *openTag = [self getCurrentlyOpenTag:textContent];
    if (openTag) {
        [self.textView insertText:[NSString stringWithFormat:@"[/%@]", openTag]];
    }
}

/*
 * Insert the appropriate closing tag, if any.
 *
 * First, scan backwards for [code]. If so, and there's no [/code] between there and here, then
 * the insertion is always [/code] (bbcode within [code] isn't interpreted).
 *
 * Scan backwards looking for [.
 * - If we find a [/tag], scan backwards for its [tag] and continue search from there.
 * - If we find [tag], trim =part if any, and insert [/tag].
 *
 * XXX should have a list of bbcode tags, and only consider those?
 */

/* Tests:
 * "[code] [b]"                -> TRUE
 * "[code] [b] [/code]"        -> FALSE
 * "[code] [b] [/code][code]"  -> TRUE
 * "[code=cpp] [b]"            -> TRUE
 * "[/code]"                   -> FALSE
 * "[codemonkey] [b]"          -> FALSE
 * "[code][codemonkey]"        -> TRUE
 */
- (BOOL)hasOpenCodeTag:(NSString *)content
{
    NSRange codeRange = [content rangeOfString:@"[code" options:NSBackwardsSearch];
    if (codeRange.location == NSNotFound || NSMaxRange(codeRange) >= content.length) {
        return NO;
    }
    
    // If it's a false alarm like [codemonkey], keep looking.
    unichar nextChar = [content characterAtIndex:NSMaxRange(codeRange) /* [code */];
    if (![TagNameTerminators() characterIsMember:nextChar]) {
        return [self hasOpenCodeTag:[content substringToIndex:codeRange.location]];
    }
    
    // Is this still open?
    return [[content substringFromIndex:codeRange.location] rangeOfString:@"[/code]"].location == NSNotFound;
}

/*
 * Tests:
 * "[b][i]"              -> "i"
 * "[b][i][/i]"          -> "b"
 * "[b][/b]"             -> nil
 * "[url=foo]"           -> "url"
 * "[url=foo][b][i][/b]" -> "url"
 * "["                   -> "nil"
 * "[foo][/x"            -> "foo"
 * "[foo attr]"          -> "foo"
 * "[code][b]"           -> "code"
 * "[b][code][/code]"    -> "b"
 * "[list][*]"           -> "list"
 */
- (NSString *)getCurrentlyOpenTag:(NSString *)content
{
    // Find start of preceding tag (opener or closer).
    NSUInteger startingBracket = [content rangeOfString:@"[" options:NSBackwardsSearch].location;
    if (startingBracket == NSNotFound) {
        return nil;
    }
    
    if (startingBracket >= content.length - 1) {
        // Incomplete tag, keep going.
        return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
    }
    
    // If it's a closer, find its opener.
    if ([content characterAtIndex:(startingBracket + 1)] == '/') {
        NSRange tagRange = [[content substringFromIndex:startingBracket] rangeOfString:@"]"];
        if (tagRange.location == NSNotFound) {
            // Not a proper tag, keep searching backwards.
            return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
        }
        
        tagRange = NSMakeRange(startingBracket + 2, tagRange.location - 2);
        NSString *tagname = [content substringWithRange:tagRange];
        
        NSUInteger openerLocation =
        [content rangeOfString:
         [NSString stringWithFormat:@"[%@]", tagname] options:NSBackwardsSearch].location;
        
        if (openerLocation == NSNotFound) {
            // Might be [tag=attr]
            openerLocation =
            [content rangeOfString:
             [NSString stringWithFormat:@"[%@=", tagname] options:NSBackwardsSearch].location;
        }
        
        if (openerLocation == NSNotFound) {
            // Might be [tag attr=val]
            openerLocation =
            [content rangeOfString:
             [NSString stringWithFormat:@"[%@ ", tagname] options:NSBackwardsSearch].location;
        }
        
        if (openerLocation == NSNotFound) {
            // Never opened, keep searching backwards from the starting bracket.
            return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
        }
        
        // Now that we've matched [tag]...[/tag], keep looking back for an outer [tag2] that
        // might still be open.
        return [self getCurrentlyOpenTag:[content substringToIndex:openerLocation]];
    }
    
    // We have an opener! Find the end of the tag name.
    NSRange tagRange = [content rangeOfCharacterFromSet:TagNameTerminators()
                                                options:0
                                                  range:NSMakeRange(startingBracket + 1, content.length - startingBracket - 1)];
    if (tagRange.location == NSNotFound) {
        // Malformed, keep looking.
        return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
    }
    
    tagRange.length--; // Omit the ] or =;
    NSString *tagName = [content substringWithRange:NSMakeRange(startingBracket + 1, tagRange.location - startingBracket - 1)];
    if ([tagName isEqualToString:@"*"]) {
        return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
    }
    
    return tagName;
}

static NSCharacterSet * TagNameTerminators(void)
{
    return [NSCharacterSet characterSetWithCharactersInString:@"]= "];
}

@end
