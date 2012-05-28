//
//  ReloadingWebViewController.m
//  Awful
//
//  Created by Nolan Waite on 12-05-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ReloadingWebViewController.h"
#import "GRMustache.h"
#import "PostContext.h"
#import "AwfulPost.h"

@interface ReloadingWebViewController ()

@property (strong, nonatomic) NSURL *template;

@end

@implementation ReloadingWebViewController
{
    NSDictionary *_context;
}

@synthesize template = _template;

- (id)initWithTemplate:(NSURL *)template
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.template = template;
        self.title = @"Test Fixture Thread";
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSAssert(NO, @"need a template");
    return nil;
}

- (void)loadView
{
    self.view = [[UIWebView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIWebView *webView = (UIWebView *)self.view;
    NSString *render = [GRMustacheTemplate renderObject:self.context
                                      fromContentsOfURL:self.template
                                                  error:NULL];
    [webView loadHTMLString:render baseURL:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (NSDictionary *)context
{
    if (_context) return _context;
    NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"fixture"
                                                          withExtension:@"json"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSUInteger options = NSJSONReadingMutableContainers;
    NSMutableDictionary *context = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:options
                                                                     error:NULL];
    NSString *device = @"iphone";
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        device = @"ipad";
    }
    [context setObject:device forKey:@"device"];
    _context = context;
    return _context;
}

@end
