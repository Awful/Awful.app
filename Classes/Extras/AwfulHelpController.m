//
//  AwfulHelpController.m
//  Awful
//
//  Created by Regular Berry on 6/28/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHelpController.h"

@implementation AwfulHelpBox

@synthesize title = _title;
@synthesize answer = _answer;

-(void)dealloc
{
    [_title release];
    [_answer release];
    [super dealloc];
}

@end

@implementation AwfulQA

@synthesize question = _question;
@synthesize answer = _answer;

-(id)initWithQuestion : (NSString *)question answer : (NSString *)answer
{
    if((self = [super init])) {
        _question = [question retain];
        _answer = [answer retain];
    }
    return self;
}

+(id)withQuestion : (NSString *)question answer : (NSString *)answer
{
    return [[[AwfulQA alloc] initWithQuestion:question answer:answer] autorelease];
}

-(void)dealloc
{
    [_question release];
    [_answer release];
    [super dealloc];
}

@end

@implementation AwfulHelpController

@synthesize scroller = _scroller;
@synthesize helpBox = _helpBox;
@synthesize firstBox = _firstBox;
@synthesize content = _content;
@synthesize helpBoxes = _helpBoxes;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.title = @"How do I...";
        _content = [[NSMutableArray alloc] init];
        
        AwfulQA *thread_jump = [AwfulQA withQuestion:@"Do thread actions?" answer:@"Long press on the thread in the thread list to bring up 'First Page', 'Last Page', and 'Mark Unread'."];
        [_content addObject:thread_jump];
        
        AwfulQA *full = [AwfulQA withQuestion:@"View fullscreen?" answer:@"Triple-tap on the page."];
        [_content addObject:full];
        
        AwfulQA *page = [AwfulQA withQuestion:@"Reply, Vote, etc?" answer:@"Tap the action button in the toolbar while reading a thread."];
        [_content addObject:page];
        
        AwfulQA *cust = [AwfulQA withQuestion:@"Tweak settings?" answer:@"Open up Settings.app on your device."];
        [_content addObject:cust];
        
        AwfulQA *image = [AwfulQA withQuestion:@"View image detail?" answer:@"Long-press on the image."];
        [_content addObject:image];
        
        _helpBoxes = nil;
        
    }
    return self;
}

-(id)init 
{
    return [self initWithNibName:@"AwfulHelpController" bundle:[NSBundle mainBundle]];
}

- (void)dealloc
{
    [_scroller release];
    [_helpBox release];
    [_firstBox release];
    [_content release];
    [_helpBoxes release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    self.helpBoxes = [[[NSMutableArray alloc] init] autorelease];
    float center_y = self.firstBox.center.y;
    for(AwfulQA *qa in self.content) {
        [[NSBundle mainBundle] loadNibNamed:@"AwfulHelpBox" owner:self options:nil];
        AwfulHelpBox *box = self.helpBox;
        [self.helpBoxes addObject:box];
        self.helpBox = nil;
        
        box.title.text = qa.question;
        box.answer.text = qa.answer;
        
        center_y += self.firstBox.bounds.size.height + 20;
        box.center = CGPointMake(self.view.center.x, center_y);
        [self.view addSubview:box];
    }
    
    self.scroller.contentSize = CGSizeMake(self.view.frame.size.width, center_y + 100);
    [super viewDidLoad];
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.scroller = nil;
    self.helpBox = nil;
    self.firstBox = nil;
    self.helpBoxes = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
