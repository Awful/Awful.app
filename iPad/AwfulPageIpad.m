//
//  AwfulPageIpad.m
//  Awful
//
//  Created by Sean Berry on 3/13/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageIpad.h"
#import "AwfulSplitViewController.h"
#import "AwfulActions.h"
#import "AwfulPageCount.h"
#import "AwfulVoteActions.h"
#import "AwfulThreadActions.h"
#import "AwfulPost.h"
#import "AwfulPostActions.h"
#import "AwfulLoginController.h"
#import "AwfulPageDataController.h"

@implementation AwfulPageIpad : AwfulPage

@synthesize pageButton, popController, pagePicker;
@synthesize actions, lastTouch, ratingButton;
@synthesize listBarButtonItem = _listBarButtonItem;
@synthesize popOverController = _popOverController;

- (void) viewDidLoad
{
    [super viewDidLoad];
    //[self makeCustomToolbars];
    //[self setThreadTitle:self.thread.title];
}

- (void) viewDidUnload
{
    /*self.pageButton = nil;
     self.ratingButton = nil;
     self.popController = nil;
     self.pagePicker = nil;
     self.actions = nil;*/
    
    [super viewDidUnload];
}

-(IBAction)tappedList : (id)sender
{
    AwfulSplitViewController *splitter = (AwfulSplitViewController *)self.parentViewController;
    UIViewController *vc = [splitter.viewControllers objectAtIndex:0];
    
    self.popOverController = [[UIPopoverController alloc] initWithContentViewController:vc];
    [self.popOverController presentPopoverFromBarButtonItem:self.listBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

-(void)makeCustomToolbars
{
    NSMutableArray *items = [NSMutableArray array];
    UIBarButtonItem *space;
    
    if (isLoggedIn()) {
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 140, 40)];
        
        
        UIImage *starImage;
        if (self.isBookmarked) {
            starImage = [UIImage imageNamed:@"star_on.png"];
        } else {
            starImage = [UIImage imageNamed:@"star_off.png"];
        }
        
        UIBarButtonItem *bookmark = [[UIBarButtonItem alloc] initWithImage:starImage 
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self 
                                                                    action:@selector(bookmarkThread:)];
        
        UIImage *ratingImage;
        if ([self.thread.threadRating intValue] < 6)
            ratingImage = [UIImage imageNamed:[NSString stringWithFormat:@"%dstars.gif", self.thread.threadRating]];
        else
            ratingImage = [UIImage imageNamed:@"0stars.gif"];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setBackgroundImage:ratingImage forState:UIControlStateNormal];
        button.frame = CGRectMake(0,0,ratingImage.size.width, ratingImage.size.height);
        [button addTarget:self action:@selector(rateThread:) forControlEvents:UIControlEventTouchUpInside];
        self.ratingButton = [[UIBarButtonItem alloc] initWithCustomView:button];
        
        
        UIBarButtonItem *reply = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(reply)];
        space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        
        
        [items addObject:space];
        [items addObject:bookmark];
        [items addObject:self.ratingButton];
        [items addObject:reply];
        
        
        [toolbar setItems:items];
        
        UIBarButtonItem *toolbar_cust = [[UIBarButtonItem alloc] initWithCustomView:toolbar];
        self.navigationItem.rightBarButtonItem = toolbar_cust;
    }
    
    items = [NSMutableArray array];
    
    UIBarButtonItem *backNav = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowleft-ipad.png"] style:UIBarButtonItemStylePlain target:self action:@selector(backPage)];
    
    /*AwfulNavigator *nav = getNavigator();
     if (![nav.historyManager isBackEnabled]) {
     backNav.enabled = NO;
     }*/
    
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(hardRefresh)];
    
    space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    UIBarButtonItem *first = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(hitFirst)];
    
    if (self.pages.currentPage > 1) {
        first.enabled = NO;
    }
    
    UIBarButtonItem *prev = [[UIBarButtonItem alloc] 
                             initWithImage:[UIImage imageNamed:@"back.png"] 
                             style:UIBarButtonItemStylePlain 
                             target:self 
                             action:@selector(prevPage)];
    if (self.pages.currentPage > 1) {
        prev.enabled = NO;
    }
    
    NSString *pagesTitle = @"Loading...";
    if (self.pages.description) {
        pagesTitle = self.pages.description;
    }
    
    UIBarButtonItem *pages = [[UIBarButtonItem alloc] initWithTitle:pagesTitle style:UIBarButtonItemStyleBordered target:self action:@selector(pageSelection)];
    
    self.pageButton = pages;
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(nextPage)];
    if([self.pages onLastPage]) {
        next.enabled = NO;
    }
    
    UIBarButtonItem *last = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward target:self action:@selector(hitLast)];
    if([self.pages onLastPage]) {
        last.enabled = NO;
    }
    
    [items addObject:backNav];
    [items addObject:refresh];
    [items addObject:space];
    [items addObject:first];
    [items addObject:prev];
    [items addObject:pages];
    [items addObject:next];
    [items addObject:last];
    
    [self setToolbarItems:items];
    
    [self.navigationController setToolbarHidden:NO animated:YES];
}

-(void)hitActions
{
    //AwfulNavigator *nav = getNavigator();
    //[nav tappedAction];
}

-(void) showActions:(NSString *)post_id
{
    
    if(![post_id isEqualToString:@""]) {
        for(AwfulPost *post in self.dataController.posts) {
            if([post.postID isEqualToString:post_id]) {
                
                AwfulPostActions *post_actions = [[AwfulPostActions alloc] initWithAwfulPost:post page:self];
                self.actions = post_actions;
                
                UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Post Actions" 
                                                                   delegate:self.actions
                                                          cancelButtonTitle:nil
                                                     destructiveButtonTitle:nil
                                                          otherButtonTitles:nil];
                for (NSString *title in actions.titles) {
                    [sheet addButtonWithTitle:title];
                }
                CGRect frame = CGRectMake(self.lastTouch.x, self.lastTouch.y, 0, 0);
                [sheet showFromRect:frame inView:self.view animated:YES];
            }
        }
    }
    
}

#pragma mark -
#pragma mark UIPickerViewDataSource
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)thePickerView numberOfRowsInComponent:(NSInteger)component {
    
    return self.pages.totalPages;
}

- (NSString *)pickerView:(UIPickerView *)thePickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    int page = row;
    page++;
    return [NSString stringWithFormat:@"%d", page];
}

- (void) gotoPageClicked
{
    /*int pageSelected = [self.pagePicker selectedRowInComponent:0] + 1;
     AwfulPage *page = [[[self class] alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeSpecific pageNum:pageSelected];
     loadContentVC(page);*/
    [self.popController dismissPopoverAnimated:YES];
}

#pragma mark -
#pragma mark Page Navigation

-(void)hitMore
{
    //AwfulExtrasController *extras = [[AwfulExtrasController alloc] init];
    //AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    //[del.splitController.pageController pushViewController:extras animated:YES];
}

-(void)hitFirst
{
    //AwfulPage *first_page = [[[self class] alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeFirst];
    //loadContentVC(first_page);
}


-(void)hitLast
{
    if(![self.pages onLastPage]) {
        //AwfulPage *last_page = [[[self class] alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeLast];
        //loadContentVC(last_page);
    }
}

- (void)pageSelection
{   
    if(self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    self.pagePicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, 320, 216)];
    self.pagePicker.dataSource = self;
    self.pagePicker.delegate = self;
    [self.pagePicker selectRow:[self.pages currentPage]-1
                   inComponent:0
                      animated:NO];
    
    self.pagePicker.showsSelectionIndicator = YES;
    
    UIButton *goButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [goButton addTarget:self action:@selector(gotoPageClicked) forControlEvents:UIControlEventTouchUpInside];
    goButton.frame = CGRectMake(0, self.pagePicker.frame.size.height, 320, 40);
    
    [goButton setTitle:@"Goto Page" forState:UIControlStateNormal];
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, self.pagePicker.frame.size.height + 40)];
    
    [view addSubview:self.pagePicker]; 
    
    [view addSubview:goButton];
    
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view = view;
    self.popController = [[UIPopoverController alloc] initWithContentViewController:vc];
    
    [self.popController setPopoverContentSize:view.frame.size animated:YES];
    [self.popController presentPopoverFromBarButtonItem:self.pageButton 
                               permittedArrowDirections:UIPopoverArrowDirectionAny
                                               animated:YES];
}

-(void)hitForum
{
    if(self.thread.forum != nil) {
        /*AwfulThreadListIpad *list = [[AwfulThreadListIpad alloc] initWithAwfulForum:self.thread.forum];
         loadContentVC(list);*/
    }
}

-(void)backPage
{
    //AwfulNavigator *nav = getNavigator();
    //[nav tappedBack];
    
}
#pragma mark -
#pragma mark Handle Updates

-(void)setPages:(AwfulPageCount *)pages
{
    [super setPages:pages];
    [self.pageButton setTitle:pages.description];
}

-(void)setThreadTitle : (NSString *)in_title
{
    [super setThreadTitle:in_title];
    [self makeCustomToolbars];
    UIButton *titleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [titleButton setTitle:in_title forState:UIControlStateNormal];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateDisabled];
    
    [titleButton addTarget:self action:@selector(hitForum) forControlEvents:UIControlEventTouchUpInside];
    
    //titleButton.frame = CGRectMake(0, 0, getWidth()-50, 44);
    
    self.navigationItem.titleView = titleButton;
}

-(void)setWebView:(JSBridgeWebView *)webView
{
    [super setWebView:webView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.delegate = self;
    [webView addGestureRecognizer:tap];
    
}

- (void)handleTap:(UITapGestureRecognizer *)sender 
{     
    if (sender.state == UIGestureRecognizerStateEnded) {    
        self.lastTouch = [sender locationInView:self.view];
    } 
}

-(void)rateThread:(id)sender
{
    
    if(self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    AwfulVoteActions *vote_actions = [[AwfulVoteActions alloc] initWithAwfulThread:self.thread];
    self.actions = vote_actions;
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self.actions
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    for (NSString *title in self.actions.titles) {
        [sheet addButtonWithTitle:title];
    }
    [sheet showFromBarButtonItem:self.ratingButton animated:YES];
    
}

-(void)bookmarkThread:(id)sender;
{
    AwfulThreadActions *thread_actions = [[AwfulThreadActions alloc] initWithAwfulPage:self];
    UIBarButtonItem *button = (UIBarButtonItem *) sender;
    
    if (self.isBookmarked) {
        button.image = [UIImage imageNamed:@"star_off.png"];
        [thread_actions removeBookmark];
    } else {
        button.image = [UIImage imageNamed:@"star_on.png"];
        [thread_actions addBookmark];
    }
}

-(void)reply
{
    AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:@""];
    [post_box setThread:self.thread];
    UIViewController *vc = [ApplicationDelegate getRootController];
    [vc presentModalViewController:post_box animated:YES];
}

@end
