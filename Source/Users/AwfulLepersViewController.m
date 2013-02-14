//
//  AwfulLepersViewController.m
//  Awful
//
//  Created by me on 1/29/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLepersViewController.h"
#import "AwfulAlertView.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulHTTPClient.h"
#import "AwfulLeperCell.h"
#import "AwfulParsing.h"
#import "AwfulTheme.h"

@interface AwfulLepersViewController ()

@property (nonatomic) NSInteger currentPage;

@property (nonatomic) NSMutableArray *bans;

@property (nonatomic) NSMutableSet *banIDs;

@property (nonatomic) UIImage *cellBackgroundImage;

@end


@implementation AwfulLepersViewController

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    self.title = @"Leper's Colony";
    _bans = [NSMutableArray new];
    _banIDs = [NSMutableSet new];
    return self;
}

- (UIImage *)cellBackgroundImage
{
    if (_cellBackgroundImage) return _cellBackgroundImage;
    CGSize size = CGSizeMake(40, 56);
    UIColor *topColor = [UIColor whiteColor];
    UIColor *shadowColor = [UIColor colorWithWhite:0.5 alpha:0.2];
    UIColor *bottomColor = [UIColor colorWithWhite:0.969 alpha:1];
    
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    // Subtract 2: 1 for shadow, 1 for resizable part.
    CGRect topHalf = CGRectMake(0, 0, size.width, size.height - 2);
    
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, bottomColor.CGColor);
    CGContextFillRect(context, (CGRect){ .size = size });
    CGContextRestoreGState(context);
    
    CGContextSaveGState(context);
    CGContextMoveToPoint(context, CGRectGetMinX(topHalf), CGRectGetMinY(topHalf));
    CGContextAddLineToPoint(context, CGRectGetMinX(topHalf), CGRectGetMaxY(topHalf));
    CGContextAddLineToPoint(context, CGRectGetMinX(topHalf) + 25, CGRectGetMaxY(topHalf));
    CGContextAddLineToPoint(context, CGRectGetMinX(topHalf) + 31, CGRectGetMaxY(topHalf) - 4);
    CGContextAddLineToPoint(context, CGRectGetMinX(topHalf) + 37, CGRectGetMaxY(topHalf));
    CGContextAddLineToPoint(context, CGRectGetMaxX(topHalf), CGRectGetMaxY(topHalf));
    CGContextAddLineToPoint(context, CGRectGetMaxX(topHalf), CGRectGetMinY(topHalf));
    CGContextSetFillColorWithColor(context, topColor.CGColor);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1, shadowColor.CGColor);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIEdgeInsets capInsets = UIEdgeInsetsMake(size.height - 1, size.width - 1, 0, 0);
    _cellBackgroundImage = [image resizableImageWithCapInsets:capInsets];
    return _cellBackgroundImage;
}

#pragma mark - AwfulTableViewController

- (void)refresh
{
    [super refresh];
    [self loadPageNum:1];
}

- (BOOL)refreshOnAppear
{
    return [self.bans count] == 0;
}

- (void)retheme
{
    [super retheme];
    self.view.backgroundColor = [AwfulTheme currentTheme].threadListBackgroundColor;
    self.tableView.separatorColor = [AwfulTheme currentTheme].threadListSeparatorColor;
    for (AwfulLeperCell *cell in [self.tableView visibleCells]) {
        [self tableView:self.tableView
        willDisplayCell:cell
      forRowAtIndexPath:[self.tableView indexPathForCell:cell]];
    }
}


- (BOOL)canPullForNextPage
{
    return YES;
}

- (void)loadPageNum:(NSUInteger)pageNum
{
    [self.networkOperation cancel];
    __block id op;
    op = [[AwfulHTTPClient client] listBansOnPage:pageNum
                                             andThen:^(NSError *error, NSArray *bans)
    {
        if (![self.networkOperation isEqual:op]) return;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            self.currentPage = pageNum;
            if (pageNum == 1) {
                self.bans = [bans mutableCopy];
                [self.banIDs removeAllObjects];
                [self.tableView reloadData];
            } else {
                NSIndexSet *newBans = [bans indexesOfObjectsPassingTest:^BOOL(BanParsedInfo *ban,
                                                                              NSUInteger i,
                                                                              BOOL *_)
                {
                    return ![self.banIDs containsObject:CreateBanIDForBan(ban)];
                }];
                bans = [bans objectsAtIndexes:newBans];
                [self.bans addObjectsFromArray:bans];
                NSMutableArray *indexPaths = [NSMutableArray new];
                NSUInteger start = [self.tableView numberOfRowsInSection:0];
                NSUInteger end = start + [bans count];
                for (NSUInteger i = start; i < end; i++) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                }
                [self.tableView insertRowsAtIndexPaths:indexPaths
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            for (BanParsedInfo *ban in bans) {
                [self.banIDs addObject:CreateBanIDForBan(ban)];
            }
        }
        self.refreshing = NO;
    }];
    self.networkOperation = op;
}

static NSString * CreateBanIDForBan(BanParsedInfo *ban)
{
    return [NSString stringWithFormat:@"%@.%.2f.%@",
            @(ban.banType), [ban.banDate timeIntervalSinceReferenceDate], ban.bannedUserID];
}

- (void)nextPage
{
    [super nextPage];
    [self loadPageNum:self.currentPage + 1];
}

#pragma mark - UITableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    return [self init];
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.bans count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"LeperCell";
    AwfulLeperCell *cell = (id)[tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulLeperCell alloc] initWithReuseIdentifier:Identifier];
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 0;
        cell.accessoryView = [AwfulDisclosureIndicatorView new];
        UIImageView *background = [[UIImageView alloc] initWithImage:self.cellBackgroundImage];
        background.frame = cell.bounds;
        background.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                       UIViewAutoresizingFlexibleHeight);
        cell.backgroundView = background;
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BanParsedInfo *ban = self.bans[indexPath.row];
    return [AwfulLeperCell rowHeightWithBanReason:ban.banReason
                                            width:CGRectGetWidth(tableView.frame)];
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)baseCell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulLeperCell *cell = (id)baseCell;
    cell.usernameLabel.textColor = [AwfulTheme currentTheme].forumCellTextColor;
    cell.dateAndModLabel.textColor = [AwfulTheme currentTheme].forumCellTextColor;
    cell.reasonLabel.textColor = [AwfulTheme currentTheme].forumCellTextColor;
}

- (void)configureCell:(UITableViewCell *)baseCell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulLeperCell *cell = (id)baseCell;
    BanParsedInfo *ban = self.bans[indexPath.row];
    
    if (ban.banType == AwfulBanTypeProbation) {
        cell.imageView.image = [UIImage imageNamed:@"title-probation.png"];
    } else if (ban.banType == AwfulBanTypePermaban) {
        cell.imageView.image = [UIImage imageNamed:@"title-permabanned.gif"];
    } else {
        cell.imageView.image = [UIImage imageNamed:@"title-banned.gif"];
    }
    
    cell.usernameLabel.text = ban.bannedUserName;
    static NSDateFormatter *df;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        df = [NSDateFormatter new];
        [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [df setDateFormat:@"MM/dd/yy HH:mm"];
    });
    cell.dateAndModLabel.text = [NSString stringWithFormat:@"%@ by %@",
                                 [df stringFromDate:ban.banDate], ban.requesterUserName];
    cell.reasonLabel.text = ban.banReason;
    cell.disclosureIndicator = ban.postID ? [AwfulDisclosureIndicatorView new] : nil;
    cell.disclosureIndicator.color = [AwfulTheme currentTheme].disclosureIndicatorColor;
    cell.disclosureIndicator.highlightedColor = [AwfulTheme currentTheme].disclosureIndicatorHighlightedColor;
    
    NSString *banDescription = @"banned";
    if (ban.banType == AwfulBanTypeProbation) banDescription = @"probated";
    else if (ban.banType == AwfulBanTypePermaban) banDescription = @"permabanned";
    NSString *readableBanDate = [NSDateFormatter localizedStringFromDate:ban.banDate
                                                               dateStyle:NSDateFormatterMediumStyle
                                                               timeStyle:NSDateFormatterShortStyle];
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@ was %@ by %@ on %@: “%@”",
                               ban.bannedUserName, banDescription, ban.requesterUserName,
                               readableBanDate, ban.banReason];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BanParsedInfo *ban = self.bans[indexPath.row];
    if (!ban.postID) return;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"awful://posts/%@", ban.postID]];
    [[UIApplication sharedApplication] openURL:url];
}

@end
