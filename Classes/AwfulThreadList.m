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
#import "AwfulHistory.h"

#define CELL_UNREAD_POSTS 1
#define CELL_THREAD_TITLE 2
#define CELL_TOTAL_REPLIES 3
#define CELL_THREAD_PAGES 4
#define CELL_THREAD_KILLEDBY 5
#define CELL_STICKY 6
#define CELL_THREAD_TAG 7

#define LABEL_TAG 20
#define REFRESH_TAG 21
#define FIRST_BUTTON_TAG 22
#define LAST_BUTTON_TAG 23

#define THREAD_HEIGHT 72

#define TITLE_BAR_CELL 1
#define THREAD_CELL 2
#define PAGE_NAV_CELL 3

@implementation AwfulThreadList


#pragma mark -
#pragma mark Initialization

@synthesize forum, pages, awfulThreads;

-(id)initWithString : (NSString *)str atPageNum : (int)page_num
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        awfulThreads = [[NSMutableArray alloc] init];
        
        pages = [[PageManager alloc] init];
        pages.current = page_num;
        
        swipedRow = -1;
        
        titleBar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 45)];
        refreshButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        stopButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        
        [self configureTitleBar:str];
        
        firstPageButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        lastPageButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        
        nextPageButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        prevPageButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        
        [self configureButtons];       
                
    }
    
    return self;
}

-(id)initWithAwfulForum : (AwfulForum *)in_forum atPageNum : (int)page_num
{
    forum = [in_forum retain];
    self = [self initWithString:forum.forumName atPageNum:page_num];
    return self;
}

-(id)initWithAwfulForum : (AwfulForum *)in_forum
{
    self = [self initWithAwfulForum:in_forum atPageNum:1];
    return self;
}

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if ((self = [super initWithStyle:style])) {
    }
    return self;
}*/

- (void)dealloc {
    [stopButton release];
    [refreshButton release];
    [titleBar release];
    [firstPageButton release];
    [lastPageButton release];
    [nextPageButton release];
    [prevPageButton release];
    [awfulThreads release];
    [forum release];
    [pages release];
    [super dealloc];
}

-(void)configureTitleBar : (NSString *)title_text
{
    UIFont *f = [UIFont fontWithName:@"Helvetica-Bold" size:18.0];
    
    UILabel *forum_label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 230, 45)];
    forum_label.font = f;
    forum_label.text = title_text;
    if(title_text == nil) {
        forum_label.text = @"No Forum Selected (tap bottom-right)";
    }
    forum_label.adjustsFontSizeToFitWidth = NO;
    forum_label.textAlignment = UITextAlignmentCenter;
    forum_label.textColor = [UIColor whiteColor];
    forum_label.backgroundColor = [UIColor clearColor];
    forum_label.numberOfLines = 2;
    forum_label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    forum_label.center = CGPointMake(160, 20);
    forum_label.tag = LABEL_TAG;
    
    UILabel *page_label = [[UILabel alloc] initWithFrame:CGRectMake(275, 0, 40, 45)];
    page_label.font = [UIFont fontWithName:@"Helvetica" size:12.0];
    page_label.text = [NSString stringWithFormat:@"pg: %d", pages.current];
    page_label.numberOfLines = 2;
    page_label.textAlignment = UITextAlignmentCenter;
    page_label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    page_label.textColor = [UIColor whiteColor];
    page_label.backgroundColor = [UIColor clearColor];
    page_label.tag = PAGE_TAG;
    
    [titleBar setImage:[UIImage imageNamed:@"nav_bar_landscape_bg_iphone.png"]];
    
    titleBar.userInteractionEnabled = YES;
    titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    refreshButton.frame = CGRectMake(5, 0, 40, 40);
    refreshButton.contentMode = UIViewContentModeCenter;
    [refreshButton setImage:[UIImage imageNamed:@"reload.png"] forState:UIControlStateNormal];
    [refreshButton addTarget:self action:@selector(refresh) forControlEvents:UIControlEventTouchUpInside];
    refreshButton.tag = REFRESH_TAG;
    
    stopButton.frame = CGRectMake(5, 0, 40, 40);
    stopButton.contentMode = UIViewContentModeCenter;
    [stopButton setImage:[UIImage imageNamed:@"stop.png"] forState:UIControlStateNormal];
    [stopButton addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    stopButton.tag = REFRESH_TAG;
    
    [titleBar addSubview:forum_label];
    [titleBar addSubview:refreshButton];
    [titleBar addSubview:page_label];
    
    [page_label release];
    [forum_label release];
}

-(void)configureButtons
{
    UIImage *button_back = [UIImage imageNamed:@"btn_template_bg.png"];
    UIImage *stretch_back = [button_back stretchableImageWithLeftCapWidth:17 topCapHeight:17];
    
    firstPageButton.frame = CGRectMake(160, 5, 65, 50);
    firstPageButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    firstPageButton.backgroundColor = [UIColor clearColor];
    [firstPageButton setTitle:@"First" forState:UIControlStateNormal];
    [firstPageButton setBackgroundImage:stretch_back forState:UIControlStateNormal];
    [firstPageButton addTarget:self action:@selector(firstPage) forControlEvents:UIControlEventTouchUpInside];
    firstPageButton.tag = FIRST_BUTTON_TAG;
    
    lastPageButton.frame = CGRectMake(245, 5, 65, 50);
    lastPageButton.backgroundColor = [UIColor clearColor];
    lastPageButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [lastPageButton setTitle:@"Last" forState:UIControlStateNormal];
    [lastPageButton setBackgroundImage:stretch_back forState:UIControlStateNormal];
    [lastPageButton addTarget:self action:@selector(lastPage) forControlEvents:UIControlEventTouchUpInside];
    lastPageButton.tag = LAST_BUTTON_TAG;
    
    nextPageButton.frame = CGRectMake(270, 10, 40, 40);
    nextPageButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [nextPageButton setImage:[UIImage imageNamed:@"arrowright.png"] forState:UIControlStateNormal];
    [nextPageButton addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    
    prevPageButton.frame = CGRectMake(10, 10, 40, 40);
    prevPageButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [prevPageButton setImage:[UIImage imageNamed:@"arrowleft.png"] forState:UIControlStateNormal];
    [prevPageButton addTarget:self action:@selector(prevPage) forControlEvents:UIControlEventTouchUpInside];
}

-(void)choseForumOption : (int)option
{
    if(option == 0 && pages.current > 1) {
        [self prevPage];
    } else if(option == 0 && pages.current == 1) {
        [self nextPage];
    } else if(option == 1 && pages.current > 1) {
        [self nextPage];
    }
}

-(void)prevPage
{
    if(pages.current > 1) {
        AwfulNavController *nav = getnav();
        AwfulThreadList *prev_list = [[AwfulThreadList alloc] initWithAwfulForum:forum atPageNum:pages.current-1];
        [nav loadForum:prev_list];
        [prev_list release];
    }
}

-(void)nextPage
{
    AwfulNavController *nav = getnav();
    AwfulThreadList *next_list = [[AwfulThreadList alloc] initWithAwfulForum:forum atPageNum:pages.current+1];
    [nav loadForum:next_list];
    [next_list release];
}

-(NSString *)getSaveID
{
    return forum.forumID;
}

-(NSString *)getURLSuffix
{
    return [NSString stringWithFormat:@"forumdisplay.php?forumid=%@&pagenumber=%d", forum.forumID, pages.current];
}

-(void)loadList
{
    [awfulThreads release];
    NSMutableArray *threads = [AwfulUtil newThreadListForForumId:[self getSaveID]];
    awfulThreads = [threads retain];
    [threads release];
}

-(void)swapToView : (UIView *)v
{
    if(v == stopButton) {
        [[refreshButton superview] addSubview:stopButton];
        [refreshButton removeFromSuperview];
    } else {
        [[stopButton superview] addSubview:refreshButton];
        [stopButton removeFromSuperview];
    }
}

-(void)stop
{
    AwfulNavController *nav = getnav();
    [nav stopAllRequests];
    
    [self swapToView:refreshButton];
    
    self.view.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.25 animations:^{
        self.view.alpha = 1.0;
    }];
}

-(void)swapToStop
{
    [self swapToView:stopButton];
}

-(void)refresh
{        
    AwfulForumRefreshRequest *ref_req = [[AwfulForumRefreshRequest alloc] initWithAwfulThreadList:self];
    AwfulNavController *nav = getnav();
    [nav loadRequest:ref_req];
    [ref_req release];
}

-(void)acceptThreads : (NSMutableArray *)in_threads
{
    [self swapToView:refreshButton];
    
    [awfulThreads release];
    awfulThreads = [in_threads retain];
    
    float offwhite = 241.0/255;
    if([[forum forumName] isEqualToString:@"FYAD"]) {
        self.tableView.backgroundColor = [UIColor colorWithRed:1.0 green:204.0/255 blue:204.0/255 alpha:1.0];
    } else {
        self.tableView.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    }
    [self.tableView reloadData];
    self.view.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.25 animations:^{
        self.view.alpha = 1.0;
    }];
}

#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];
    
    if([[forum forumName] isEqualToString:@"FYAD"]) {
        self.tableView.separatorColor = [UIColor colorWithRed:0.0 green:51.0/255 blue:51.0/255 alpha:1.0];
    } else {
        self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
    }

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    AwfulNavController *nav = getnav();
    NSArray *items = [nav getToolbarItems];
    
    [self setToolbarItems:items];
    
    BOOL is_bookmarks = [[self getSaveID] isEqualToString:@"bookmarks"];
    //[self loadList];
    if(forum.forumID == nil && !is_bookmarks) {
        if([nav isLoggedIn]) {
            [nav openBookmarks];
        } else {
            [nav openForums];
        }
    } else if(!is_bookmarks) {
        [self refresh];
    }
}


/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}*/


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //[self refresh];
}

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

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations

    if([AwfulConfig allowRotation:interfaceOrientation]) {
        AwfulNavController *nav = getnav();
        [self setToolbarItems:[nav getToolbarItemsForOrientation:interfaceOrientation]];
        return YES;
    }
    return NO;
}

- (void)swipedRow:(UISwipeGestureRecognizer *)gestureRecognizer
{
    UITableViewCell *cell = (UITableViewCell *)gestureRecognizer.view;
    NSIndexPath *path = [self.tableView indexPathForCell:cell];
    
    int old_swiped = swipedRow;
    swipedRow = path.row;
    
    NSArray *paths;
    
    if(swipedRow == old_swiped) {
        swipedRow = -1;
        paths = [[NSArray alloc] initWithObjects:path, nil];
    } else if(old_swiped == -1) {
        paths = [[NSArray alloc] initWithObjects:path, nil];
    } else {
        NSIndexPath *old_path = [NSIndexPath indexPathForRow:old_swiped inSection:0];
        paths = [[NSArray alloc] initWithObjects:path, old_path, nil];
    }
    
    @try {
        [self.tableView reloadRowsAtIndexPaths:paths withRowAnimation:UISwipeGestureRecognizerDirectionLeft];
    } @catch (NSException *exception) {
    }
    [paths release];
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if([awfulThreads count] > 0) {
        [self.tableView reloadData];
    }
}

-(int)getTypeAtIndexPath : (NSIndexPath *)path
{
    int extra = 0;
    if([self isTitleBarInTable]) {
        extra = 1;
    }
    
    if(path.row == 0 && [self isTitleBarInTable]) {
        return TITLE_BAR_CELL;
    }
    
    if(path.row < [awfulThreads count] + extra) {
        return THREAD_CELL;
    }
    
    if(path.row == [awfulThreads count] + extra) {
        return PAGE_NAV_CELL;
    }
    
    NSLog(@"unknown row type in threadlist");
    return TITLE_BAR_CELL;
}

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path
{
    int diff = 0;
    if([self isTitleBarInTable]) {
        diff = 1;
    }
    
    int index = path.row - diff;
    
    AwfulThread *thread = nil;
    
    if(index < [awfulThreads count]) {
        thread = [awfulThreads objectAtIndex:index];
    } else {
        NSLog(@"why am I getting a thread out of bounds?");
    }
    
    return thread;
}

-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread
{
    float offwhite = 241.0/255;
    UIColor *back_color = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    
    if([[forum forumName] isEqualToString:@"FYAD"]) {
        back_color = [UIColor colorWithRed:255.0/255 green:204.0/255 blue:255.0/255 alpha:1.0];
    } else if(thread.category == 0) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    } else if(thread.category == 1) {
        back_color = [UIColor colorWithRed:242.0/255 green:220.0/255 blue:220.0/255 alpha:1.0];
    } else if(thread.category == 2) {
        back_color = [UIColor colorWithRed:242.0/255 green:242.0/255 blue:220.0/255 alpha:1.0];
    } else if(thread.alreadyRead) {
        back_color = [UIColor colorWithRed:219.0/255 green:232.0/255 blue:245.0/255 alpha:1.0];
    }
    
    return back_color;
}

#pragma mark -
#pragma mark Table view data source

-(BOOL)isTitleBarInTable
{
    return YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    int total = [awfulThreads count];
    if([self isTitleBarInTable]) {
        total++;
    }
    
    // bottom page-nav cell
    if([awfulThreads count] > 0) {
        total++;
    }
    
    return total;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    float height = 5;
    
    int type = [self getTypeAtIndexPath:indexPath];
    switch (type) {
        case TITLE_BAR_CELL:
            height = 45;
            break;
        case THREAD_CELL:
            height = THREAD_HEIGHT;
            break;
        case PAGE_NAV_CELL:
            height = 60;
            break;
            
        default:
            break;
    }
    
    return height;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *reg = @"Cell";
    static NSString *title_str = @"titleCell";
    static NSString *pagenav_str = @"PageNav";
    
    NSString *ident = nil;
    
    int type = [self getTypeAtIndexPath:indexPath];
    if(type == TITLE_BAR_CELL) {
        ident = title_str;
    } else if(type == THREAD_CELL) {
        ident = reg;
    } else if(type == PAGE_NAV_CELL) {
        ident = pagenav_str;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    
    if (cell == nil) {
        if(ident == title_str) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ident] autorelease];
            [cell.contentView addSubview:titleBar];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if(ident == pagenav_str) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ident] autorelease];
            cell.textLabel.textAlignment = UITextAlignmentCenter;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell = [self makeThreadListCell];
        }
    }
    
    if(type == PAGE_NAV_CELL) {
        cell.textLabel.text = [NSString stringWithFormat:@"Page %d", pages.current];
        [nextPageButton removeFromSuperview];
        if(pages.current > 1) {
            [cell addSubview:prevPageButton];
        } else {
            [prevPageButton removeFromSuperview];
        }
        if([awfulThreads count] == 40) {
            [cell addSubview:nextPageButton];
        }
    }
    
    // Configure the cell...
    if(type == THREAD_CELL) {

        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        
        cell.contentView.backgroundColor = [self getBackgroundColorForThread:thread];
        
        if(thread.isLocked) {
            cell.contentView.alpha = 0.5;
        } else {
            cell.contentView.alpha = 1.0;
        }
        
        
        UIButton *unread = (UIButton *)[cell.contentView viewWithTag:CELL_UNREAD_POSTS];
        UILabel *title_label = (UILabel *)[cell.contentView viewWithTag:CELL_THREAD_TITLE];
        UILabel *pages_label = (UILabel *)[cell.contentView viewWithTag:CELL_THREAD_PAGES];
        
        // content of labels
        int total_pages = ((thread.totalReplies-1)/getPostsPerPage()) + 1;
        pages_label.text = [NSString stringWithFormat:@"Pages: %d", total_pages];
        
        NSString *unread_str = [NSString stringWithFormat:@"%d", thread.numUnreadPosts];
        [unread setTitle:unread_str forState:UIControlStateNormal];
        
        title_label.text = thread.threadTitle;
        
        
        // visibility of labels
        if(indexPath.row == swipedRow) {
            unread.hidden = YES;
            pages_label.hidden = YES;
        } else {
            unread.hidden = NO;
            pages_label.hidden = NO;
        }
        
        if(thread.numUnreadPosts == -1) {
            unread.hidden = YES;
        } else if(thread.numUnreadPosts == 0) {
            [unread setTitle:@"0" forState:UIControlStateNormal];
            unread.alpha = 0.5;
        } else {
            unread.alpha = 1.0;
        }
        
        // size and positioning of labels
        float title_width = getWidth() - 100;
        if(thread.numUnreadPosts == -1) {
            title_width = getWidth() - 40;
        }
        
        CGSize title_size = [thread.threadTitle sizeWithFont:[AwfulConfig getCellTitleFont] constrainedToSize:CGSizeMake(title_width, 60)];
        title_label.frame = CGRectMake(20, 0, title_width, 60);
        
        CGSize unread_size = [unread_str sizeWithFont:[AwfulConfig getCellUnreadFont]];
        unread.frame = CGRectMake(getWidth()-30-unread_size.width, THREAD_HEIGHT/2 - 10, unread_size.width+20, 20);
        
        //pages_label.frame = CGRectMake(5, 26, 100, 10);
        pages_label.frame = CGRectMake(20, (THREAD_HEIGHT-title_size.height)/2 + title_size.height - 4, 100, 10);
                              
        // Stickied?
        UIView *old_sticky = [cell.contentView viewWithTag:CELL_STICKY];
        [old_sticky removeFromSuperview];
                              
        if(thread.isStickied) {            
            UIImageView *stick = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sticky.png"]];
            stick.frame = CGRectMake(CGRectGetMinX(title_label.frame)-16, (THREAD_HEIGHT-title_size.height)/2 - 3, 12, 12);
            stick.tag = CELL_STICKY;
            [cell.contentView addSubview:stick];
            [stick release];
        }
        
        // Swiped?
        if(indexPath.row == swipedRow) {
            title_label.frame = CGRectMake(CGRectGetMinX(title_label.frame), CGRectGetMinY(title_label.frame), CGRectGetWidth(title_label.frame)-110, CGRectGetHeight(title_label.frame));
            [cell addSubview:firstPageButton];
            [cell addSubview:lastPageButton];
        } else {
            UIView *first_throwaway = [cell viewWithTag:FIRST_BUTTON_TAG];
            [first_throwaway removeFromSuperview];
            UIView *last_throwaway = [cell viewWithTag:LAST_BUTTON_TAG];
            [last_throwaway removeFromSuperview];
        }
    }
    
    return cell;
}


-(UITableViewCell *)makeThreadListCell
{
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"] autorelease];
    
    UIImage *number_back = [UIImage imageNamed:@"number-background.png"];
    UIImage *stretch_back = [number_back stretchableImageWithLeftCapWidth:15.5 topCapHeight:9.5];
    
    UIButton *unread_button = [UIButton buttonWithType:UIButtonTypeCustom];
    unread_button.frame = CGRectMake(50, 5, 32, 20);
    unread_button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [unread_button setBackgroundImage:stretch_back forState:UIControlStateDisabled];
    unread_button.enabled = NO;
    unread_button.titleLabel.font = [AwfulConfig getCellUnreadFont];;
    unread_button.titleLabel.textAlignment = UITextAlignmentCenter;
    unread_button.titleLabel.textColor = [UIColor whiteColor];
    unread_button.tag = CELL_UNREAD_POSTS;
    
    UILabel *pages_label = [[UILabel alloc] initWithFrame:CGRectMake(277, 40, 35, 10)];
    pages_label.font = [AwfulConfig getCellPagesFont];
    pages_label.tag = CELL_THREAD_PAGES;
    pages_label.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    pages_label.textAlignment = UITextAlignmentLeft;
    pages_label.backgroundColor = [UIColor clearColor];
    pages_label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    
    UILabel *title_label = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, getWidth()-80, 68)];
    title_label.numberOfLines = 3;
    title_label.textAlignment = UITextAlignmentLeft;
    title_label.tag = CELL_THREAD_TITLE;
    title_label.backgroundColor = [UIColor clearColor];
    title_label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title_label.font = [AwfulConfig getCellTitleFont];
    
    float offwhite = 241.0/255;
    cell.contentView.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    [cell.contentView addSubview:title_label];
    [cell.contentView addSubview:unread_button];
    [cell.contentView addSubview:pages_label];
    
    if([self isTitleBarInTable]) {
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedRow:)];
        swipe.direction = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
        [cell addGestureRecognizer:swipe];
        [swipe release];
    }
    
    [title_label release];
    [pages_label release];
    
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
     
    int type = [self getTypeAtIndexPath:indexPath];
    if(type == THREAD_CELL) {
        
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        
        if(thread.threadID != nil) {
            int start = THREAD_POS_NEWPOST;
            if(thread.numUnreadPosts == -1) {
                start = THREAD_POS_FIRST;
            } else if(thread.numUnreadPosts == 0) {
                start = THREAD_POS_LAST;
                // if the last page is full, it won't work if you go for &goto=newpost
                // therefore I'm setting it to last page here
            }
            
            AwfulNavController *nav = getnav();
            AwfulPage *thread_detail = [[AwfulPage alloc] initWithAwfulThread:thread startAt:start];
            [nav loadPage:thread_detail];
            [thread_detail release];  
        }
    }
}

-(void)firstPage
{
    int spot = swipedRow;
    if([self isTitleBarInTable]) {
        spot--;
    }
    
    if(spot >= [awfulThreads count]) {
        return;
    }
    
    AwfulThread *thread = [awfulThreads objectAtIndex:spot];
    if(thread.threadID != nil) {
    
        AwfulNavController *nav = getnav();
        AwfulPage *thread_detail = [[AwfulPage alloc] initWithAwfulThread:thread startAt:THREAD_POS_FIRST];
        [nav loadPage:thread_detail];
        [thread_detail release];
    }
}

-(void)lastPage
{
    int spot = swipedRow;
    if([self isTitleBarInTable]) {
        spot--;
    }
    if(spot >= [awfulThreads count]) {
        return;
    }
    
    AwfulThread *thread = [awfulThreads objectAtIndex:spot];
    if(thread.threadID != nil) {
        
        AwfulNavController *nav = getnav();
        AwfulPage *thread_detail = [[AwfulPage alloc] initWithAwfulThread:thread startAt:THREAD_POS_LAST];
        [nav loadPage:thread_detail];
        [thread_detail release];
    }
}

-(void)slideToBottom
{
    /*if([awfulThreads count] > 0) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:[awfulThreads count]-1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }*/
}

-(void)slideToTop
{
    /*if([awfulThreads count] > 0) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }*/
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}

#pragma mark -
#pragma AwfulHistoryRecorder

-(id)newRecordedHistory
{
    AwfulHistory *hist = [[AwfulHistory alloc] init];
    hist.pageNum = pages.current;
    hist.modelObj = forum;
    hist.historyType = AWFUL_HISTORY_THREADLIST;
    return hist;
}

-(id)initWithAwfulHistory : (AwfulHistory *)history
{
    return [self initWithAwfulForum:history.modelObj atPageNum:history.pageNum];
}

-(void)setRecorder : (AwfulHistory *)history
{
    
}

@end

