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

@property (copy, nonatomic) NSString *folderPath;

@end

@implementation ReloadingWebViewController
{
    NSDictionary *_context;
}

@synthesize folderPath = _folderPath;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self init];
}

- (id)initWithFolderPath:(NSString *)folderPath
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.folderPath = folderPath;
    }
    return self;
}

- (void)loadView
{
    self.view = [[UIWebView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIWebView *webView = (UIWebView *)self.view;
    NSString *templateName = @"phone-template.html";
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        templateName = @"pad-template.html";
    }
    NSString *path = [self.folderPath stringByAppendingPathComponent:templateName];
    NSString *render = [GRMustacheTemplate renderObject:self.context
                                     fromContentsOfFile:path
                                                  error:NULL];
    [webView loadHTMLString:render baseURL:nil];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (NSDictionary *)context
{
    if (_context) return _context;
    NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"fixture"
                                                          withExtension:@"json"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    _context = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return _context;
}

@end
