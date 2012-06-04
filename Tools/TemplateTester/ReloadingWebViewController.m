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

@property (readonly, nonatomic) NSURL *htmlFile;

@property (strong, nonatomic) NSDate *lastModified;

@property (strong, nonatomic) NSTimer *timer;

@property (readonly, strong, nonatomic) NSMutableDictionary *context;

@end

@implementation ReloadingWebViewController

- (id)initWithTemplate:(NSURL *)template
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.template = template;
        self.title = @"Test Thread";
    }
    return self;
}

@synthesize template = _template;
@synthesize lastModified = _lastModified;
@synthesize timer = _timer;
@synthesize context = _context;

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
    [self loadTemplateIntoWebView];
}

- (void)loadTemplateIntoWebView
{
    UIWebView *webView = (UIWebView *)self.view;
    NSString *css = [NSString stringWithContentsOfURL:self.template
                                             encoding:NSUTF8StringEncoding
                                                error:NULL];
    [self.context setObject:css forKey:@"css"];
    NSString *render = [GRMustacheTemplate renderObject:self.context
                                      fromContentsOfURL:self.htmlFile
                                                  error:NULL];
    [webView loadHTMLString:render baseURL:nil];
}

- (NSURL *)htmlFile {
    NSURL *folder = [self.template URLByDeletingLastPathComponent];
    return [folder URLByAppendingPathComponent:@"posts.html"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:.33
                                                  target:self
                                                selector:@selector(reloadIfNeeded:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)reloadIfNeeded:(NSTimer *)timer
{
    NSDate *lastModified;
    [self.template getResourceValue:&lastModified
                             forKey:NSURLContentModificationDateKey
                              error:NULL];
    if (self.lastModified && [lastModified compare:self.lastModified] == NSOrderedDescending) {
        [self loadTemplateIntoWebView];
    }
    self.lastModified = lastModified;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.timer invalidate];
    self.timer = nil;
    [super viewWillDisappear:animated];
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
    _context = [NSJSONSerialization JSONObjectWithData:data options:options error:NULL];
    NSString *device = @"iphone";
    NSString *deviceWidth = @"device-width";
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        device = @"ipad";
        deviceWidth = @"80%";
    }
    [_context setObject:device forKey:@"device"];
    [_context setObject:deviceWidth forKey:@"device-width"];
    return _context;
}

@end
