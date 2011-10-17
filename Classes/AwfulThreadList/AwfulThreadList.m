//
//  AwfulThreadList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadList.h"
#import "AwfulThread.h"
#import "AwfulAppDelegate.h"
#import "AwfulPage.h"
#import "AwfulUtil.h"
#import "TFHpple.h"
#import "AwfulParse.h"
#import "AwfulForumRefreshRequest.h"
#import "AwfulConfig.h"
#import "AwfulPageCount.h"
#import "AwfulLoginController.h"
#import "AwfulNavigator.h"
#import "AwfulRequestHandler.h"
#import "AwfulNavigatorLabels.h"
#import "AwfulUtil.h"
#import "AwfulThreadListActions.h"

#define THREAD_HEIGHT 72

@implementation AwfulThreadCell

@synthesize threadTitleLabel = _threadTitleLabel;
@synthesize pagesLabel = _pagesLabel;
@synthesize unreadButton = _unreadButton;
@synthesize sticky = _sticky;
@synthesize thread = _thread;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self=[super initWithCoder:aDecoder])) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(openThreadlistOptions)];
        [self addGestureRecognizer:press];
        [press release];
    }
    return self;
}

-(void)dealloc
{
    [_threadTitleLabel release];
    [_pagesLabel release];
    [_unreadButton release];
    [_thread release];
    [_sticky release];
    [super dealloc];
}

-(void)setUnreadButton:(UIButton *)unreadButton
{
    if(unreadButton != _unreadButton) {
        [_unreadButton release];
        _unreadButton = [unreadButton retain];
        UIImage *number_back = [UIImage imageNamed:@"number-background.png"];
        UIImage *stretch_back = [number_back stretchableImageWithLeftCapWidth:15.5 topCapHeight:9.5];
        [_unreadButton setBackgroundImage:stretch_back forState:UIControlStateDisabled];
    }
}

-(void)configureForThread:(AwfulThread *)thread
{
    self.thread = thread;
    self.contentView.backgroundColor = [self getBackgroundColorForThread:thread];
    
    if(thread.isLocked) {
        self.contentView.alpha = 0.5;
    } else {
        self.contentView.alpha = 1.0;
    }
    
    // Content
    int total_pages = ((thread.totalReplies-1)/getPostsPerPage()) + 1;
    self.pagesLabel.text = [NSString stringWithFormat:@"Pages: %d", total_pages];
    
    NSString *unread_str = [NSString stringWithFormat:@"%d", thread.totalUnreadPosts];
    [self.unreadButton setTitle:unread_str forState:UIControlStateNormal];
    
    self.threadTitleLabel.text = thread.title;
    
    self.unreadButton.hidden = NO;
    self.unreadButton.alpha = 1.0;
    
    float goal_width = self.frame.size.width-100;
    
    if(thread.totalUnreadPosts == -1) {
        self.unreadButton.hidden = YES;
        goal_width += 60;
    } else if(thread.totalUnreadPosts == 0) {
        [self.unreadButton setTitle:@"0" forState:UIControlStateNormal];
        self.unreadButton.alpha = 0.5;
    }
    
    // size and positioning of labels   
    CGSize title_size = [thread.title sizeWithFont:self.threadTitleLabel.font constrainedToSize:CGSizeMake(goal_width, 60)];
    
    float y_pos = (THREAD_HEIGHT - title_size.height)/2 - 4;
    self.threadTitleLabel.frame = CGRectMake(20, y_pos, title_size.width, title_size.height);
    
    CGSize unread_size = [unread_str sizeWithFont:self.unreadButton.titleLabel.font];
    float unread_x = self.frame.size.width-30-unread_size.width;
    self.unreadButton.frame = CGRectMake(unread_x, THREAD_HEIGHT/2 - 10, unread_size.width+20, 20);
    
    self.pagesLabel.frame = CGRectMake(20, CGRectGetMaxY(self.threadTitleLabel.frame)+2, 100, 10);
    
    // Stickied?
    [self.sticky removeFromSuperview];
    if(thread.isStickied) {            
        self.sticky.frame = CGRectMake(CGRectGetMinX(self.threadTitleLabel.frame)-16, (THREAD_HEIGHT-title_size.height)/2 - 3, 12, 12);
        [self.contentView addSubview:self.sticky];
    }
}

-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread
{
    float offwhite = 241.0/255;
    UIColor *back_color = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    
    if(thread.starCategory == AwfulStarCategoryBlue) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    } else if(thread.starCategory == AwfulStarCategoryRed) {
        back_color = [UIColor colorWithRed:242.0/255 green:220.0/255 blue:220.0/255 alpha:1.0];
    } else if(thread.starCategory == AwfulStarCategoryYellow) {
        back_color = [UIColor colorWithRed:242.0/255 green:242.0/255 blue:220.0/255 alpha:1.0];
    } else if(thread.seen) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    }
    
    return back_color;
}

-(void)openThreadlistOptions
{
    AwfulNavigator *nav = getNavigator();
    if(nav.actions == nil) {
        AwfulThreadListActions *actions = [[AwfulThreadListActions alloc] initWithAwfulThread:self.thread];
        [nav setActions:actions];
        [actions release];
    }
}

@end

@implementation AwfulPageNavCell

@synthesize nextButton = _nextButton;
@synthesize prevButton = _prevButton;
@synthesize pageLabel = _pageLabel;

-(void)dealloc
{
    [_nextButton release];
    [_prevButton release];
    [_pageLabel release];
    [super dealloc];
}

-(void)configureForPageCount : (AwfulPageCount *)pages thread_count : (int)count
{
    self.pageLabel.text = [NSString stringWithFormat:@"Page %d", pages.currentPage];
    
    [self.prevButton removeFromSuperview];
    if(pages.currentPage > 1) {
        [self addSubview:self.prevButton];
    }
    
    [self addSubview:self.nextButton];
}

@end

@implementation AwfulThreadList


#pragma mark -
#pragma mark Initialization

@synthesize forum = _forum;
@synthesize awfulThreads = _awfulThreads;
@synthesize threadCell = _threadCell;
@synthesize pageNavCell = _pageNavCell;
@synthesize pages = _pages;
@synthesize delegate = _delegate;
@synthesize pagesLabel = _pagesLabel;
@synthesize forumLabel = _forumLabel;

-(id)initWithString : (NSString *)str atPageNum : (int)page_num
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _awfulThreads = [[NSMutableArray alloc] init];
        _delegate = nil;
        _pages = [[AwfulPageCount alloc] init];
        _pages.currentPage = page_num;
    }
    
    return self;
}

-(id)initWithAwfulForum : (AwfulForum *)in_forum atPageNum : (int)page_num
{
    _forum = [in_forum retain];
    self = [self initWithString:_forum.name atPageNum:page_num];
    return self;
}

-(id)initWithAwfulForum : (AwfulForum *)in_forum
{
    self = [self initWithAwfulForum:in_forum atPageNum:1];
    return self;
}

- (void)dealloc {
    [_awfulThreads release];
    [_forum release];
    [_pages release];
    [_pagesLabel release];
    [_forumLabel release];
    [super dealloc];
}

-(void)choseForumOption : (int)option
{
    if(option == 0 && self.pages.currentPage > 1) {
        [self prevPage];
    } else if(option == 0 && self.pages.currentPage == 1) {
        [self nextPage];
    } else if(option == 1 && self.pages.currentPage > 1) {
        [self nextPage];
    }
}

-(NSString *)getSaveID
{
    return self.forum.forumID;
}

-(NSString *)getURLSuffix
{
    return [NSString stringWithFormat:@"forumdisplay.php?forumid=%@&pagenumber=%d", self.forum.forumID, self.pages.currentPage];
}

-(void)loadList
{
    NSMutableArray *threads = [AwfulUtil newThreadListForForumId:[self getSaveID]];
    self.awfulThreads = threads;
    [threads release];
}

-(void)refresh
{        
    [self.delegate swapToStopButton];
    AwfulForumRefreshRequest *ref_req = [[AwfulForumRefreshRequest alloc] initWithAwfulThreadList:self];
    loadRequest(ref_req);
    [ref_req release];
    [UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 0.5;
    }];
}

-(void)stop
{
    self.view.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 1.0;
    }];
    AwfulNavigator *nav = getNavigator();
    [nav.requestHandler cancelAllRequests];
}

-(void)acceptThreads : (NSMutableArray *)in_threads
{
    [self.delegate swapToRefreshButton];
    [UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 1.0;
    }];
    
    self.awfulThreads = in_threads;
    
    float offwhite = 241.0/255;
    self.tableView.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    [self.tableView reloadData];
    self.view.userInteractionEnabled = YES;
}

#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];
    
    AwfulNavigatorLabels *labels = [[AwfulNavigatorLabels alloc] init];
    self.forumLabel = labels.forumLabel;
    self.pagesLabel = labels.pagesLabel;
    [labels release];
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
    
    [self.forumLabel setText:self.forum.name];
    [self.pagesLabel setText:[self.pages description]];
    self.delegate.navigationItem.titleView = self.forumLabel;
    
    UIBarButtonItem *cust = [[UIBarButtonItem alloc] initWithCustomView:self.pagesLabel];
    self.delegate.navigationItem.rightBarButtonItem = cust;
    [cust release];
        
    if([self shouldReloadOnViewLoad]) {
        [self refresh];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.pagesLabel = nil;
    self.forumLabel = nil;
}

-(BOOL)shouldReloadOnViewLoad
{
    return YES;
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return (toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}*/

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}*/

/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

-(void)setPages:(AwfulPageCount *)pages
{
    if(pages != _pages) {
        [_pages release];
        _pages = [pages retain];
        [self.pagesLabel setText:[_pages description]];
    }
}

-(AwfulThreadCellType)getTypeAtIndexPath : (NSIndexPath *)path
{    
    if(path.row < [self.awfulThreads count]) {
        return AwfulThreadCellTypeThread;
    }
    
    if(path.row == [self.awfulThreads count]) {
        return AwfulThreadCellTypePageNav;
    }
    
    return AwfulThreadCellTypeUnknown;
}

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path
{    
    if([self getTypeAtIndexPath:path] != AwfulThreadCellTypeThread) {
        return nil;
    }
    
    AwfulThread *thread = nil;
    
    if(path.row < [self.awfulThreads count]) {
        thread = [self.awfulThreads objectAtIndex:path.row];
    } else {
        NSLog(@"thread out of bounds");
    }
    
    return thread;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    int total = [self.awfulThreads count];
    
    // bottom page-nav cell
    if([self.awfulThreads count] > 0) {
        total++;
    }
    
    return total;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    float height = 5;
    
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    if(type == AwfulThreadCellTypeThread) {
        height = THREAD_HEIGHT;
    } else if(type == AwfulThreadCellTypePageNav) {
        height = 60;
    }
    
    return height;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *threadCell = @"ThreadCell";
    static NSString *pageNav = @"PageNav";
    
    NSString *ident = nil;
    
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    if(type == AwfulThreadCellTypeThread) {
        ident = threadCell;
    } else if(type == AwfulThreadCellTypePageNav) {
        ident = pageNav;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    
    if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"AwfulThreadListCells" owner:self options:nil];
        
        if(ident == pageNav) {
            cell = self.pageNavCell;
        } else {
            cell = self.threadCell;
        }
        self.threadCell = nil;
        self.pageNavCell = nil;
    }
    
    // Configure the cell...
    if(type == AwfulThreadCellTypeThread) {
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        AwfulThreadCell *thread_cell = (AwfulThreadCell *)cell;
        [thread_cell configureForThread:thread];
    } else if(type == AwfulThreadCellTypePageNav) {
        AwfulPageNavCell *nav_cell = (AwfulPageNavCell *)cell;
        [nav_cell configureForPageCount:self.pages thread_count:[self.awfulThreads count]];
    }
    
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
     
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    
    if(type == AwfulThreadCellTypeThread) {
        
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        
        if(thread.threadID != nil) {
            int start = AwfulPageDestinationTypeNewpost;
            if(thread.totalUnreadPosts == -1) {
                start = AwfulPageDestinationTypeFirst;
            } else if(thread.totalUnreadPosts == 0) {
                start = AwfulPageDestinationTypeLast;
                // if the last page is full, it won't work if you go for &goto=newpost
                // therefore I'm setting it to last page here
            }
            
            AwfulPage *thread_detail = [[AwfulPage alloc] initWithAwfulThread:thread startAt:start];
            loadContentVC(thread_detail);
            [thread_detail release];
        }
    }
}

-(IBAction)prevPage
{
    if(self.pages.currentPage > 1) {
        AwfulThreadList *prev_list = [[AwfulThreadList alloc] initWithAwfulForum:self.forum atPageNum:self.pages.currentPage-1];
        loadContentVC(prev_list);
        [prev_list release];
    }
}

-(IBAction)nextPage
{
    AwfulThreadList *next_list = [[AwfulThreadList alloc] initWithAwfulForum:self.forum atPageNum:self.pages.currentPage+1];
    loadContentVC(next_list);
    [next_list release];
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

#pragma mark -
#pragma AwfulHistoryRecorder

-(id)newRecordedHistory
{
    AwfulHistory *hist = [[AwfulHistory alloc] init];
    hist.pageNum = self.pages.currentPage;
    hist.modelObj = self.forum;
    hist.historyType = AwfulHistoryTypeThreadlist;
    return hist;
}

-(id)initWithAwfulHistory : (AwfulHistory *)history
{
    return [self initWithAwfulForum:history.modelObj atPageNum:history.pageNum];
}

#pragma mark -
#pragma mark Navigator Content

-(UIView *)getView
{
    return self.view;
}

-(AwfulActions *)getActions
{
    return nil;
}

-(void)scrollToBottom
{
    
}

@end

