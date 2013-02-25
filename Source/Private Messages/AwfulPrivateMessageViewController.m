//
//  AwfulPrivateMessageViewController.m
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageViewController.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPostsView.h"
#import "AwfulSettings.h"
#import "NSFileManager+UserDirectories.h"

@interface AwfulPrivateMessageViewController () <AwfulPostsViewDelegate>

@property (nonatomic) AwfulPrivateMessage *privateMessage;

@property (readonly) AwfulPostsView *postsView;

@property (nonatomic) NSDateFormatter *regDateFormatter;

@property (nonatomic) NSDateFormatter *postDateFormatter;

@end


@implementation AwfulPrivateMessageViewController

- (instancetype)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;;
    _privateMessage = privateMessage;
    self.title = privateMessage.subject;
    return self;
}

- (AwfulPostsView *)postsView
{
    return (id)self.view;
}

#pragma mark - UIViewController

- (void)loadView
{
    AwfulPostsView *view = [AwfulPostsView new];
    view.frame = [UIScreen mainScreen].applicationFrame;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.delegate = self;
    self.view = view;
    [self configurePostsViewSettings];
}

- (void)configurePostsViewSettings
{
    self.postsView.showImages = [AwfulSettings settings].showImages;
    self.postsView.stylesheetURL = StylesheetURLForForumWithIDAndSettings(nil, nil);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIBarButtonItem *reply;
    reply = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply
                                                          target:self action:@selector(reply)];
    self.navigationItem.rightBarButtonItem = reply;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[AwfulHTTPClient client] readPrivateMessageWithID:self.privateMessage.messageID
                                               andThen:^(NSError *error,
                                                         AwfulPrivateMessage *message)
    {
        [self.postsView reloadPostAtIndex:0];
    }];
}

#pragma mark - AwfulPostsViewDelegate

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView
{
    return 1;
}

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"innerHTML"] = self.privateMessage.innerHTML ?: @"";
    dict[@"beenSeen"] = self.privateMessage.seen ?: @NO;
    if (self.privateMessage.sentDate) {
        dict[@"postDate"] = [self.postDateFormatter stringFromDate:self.privateMessage.sentDate];
    }
    AwfulUser *sender = self.privateMessage.from;
    dict[@"authorName"] = sender.username ?: @"";
    if (sender.avatarURL) dict[@"authorAvatarURL"] = [sender.avatarURL absoluteString];
    if (sender.regdate) {
        dict[@"authorRegDate"] = [self.regDateFormatter stringFromDate:sender.regdate];
    }
    return dict;
}

// TODO DRY these up (AwfulPostsViewController has same formatters)

- (NSDateFormatter *)postDateFormatter
{
    if (_postDateFormatter) return _postDateFormatter;
    _postDateFormatter = [NSDateFormatter new];
    // Jan 2, 2003 16:05
    _postDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _postDateFormatter.dateFormat = @"MMM d, yyyy HH:mm";
    return _postDateFormatter;
}

- (NSDateFormatter *)regDateFormatter
{
    if (_regDateFormatter) return _regDateFormatter;
    _regDateFormatter = [NSDateFormatter new];
    // Jan 2, 2003
    _regDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _regDateFormatter.dateFormat = @"MMM d, yyyy";
    return _regDateFormatter;
}

@end
