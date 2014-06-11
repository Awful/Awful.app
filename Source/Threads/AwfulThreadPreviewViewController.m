//  AwfulThreadPreviewViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadPreviewViewController.h"
#import "AwfulAlertView.h"
#import "AwfulForumsClient.h"
#import "AwfulForumTweaks.h"
#import "AwfulSelfHostingAttachmentInterpolator.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTagLoader.h"

@interface AwfulThreadPreviewViewController ()

@property (strong, nonatomic) AwfulThreadCell *threadCell;

@property (strong, nonatomic) NSOperation *networkOperation;
@property (strong, nonatomic) AwfulSelfHostingAttachmentInterpolator *imageInterpolator;

@property (strong, nonatomic) AwfulPost *fakePost;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation AwfulThreadPreviewViewController

- (instancetype)initWithForum:(AwfulForum *)forum
                      subject:(NSString *)subject
                    threadTag:(AwfulThreadTag *)threadTag
           secondaryThreadTag:(AwfulThreadTag *)secondaryThreadTag
                       BBcode:(NSAttributedString *)BBcode
{
    if ((self = [super initWithBBcode:BBcode])) {
        _forum = forum;
        _subject = [subject copy];
        _threadTag = threadTag;
        _secondaryThreadTag = secondaryThreadTag;
        self.title = @"Thread Preview";
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    self.threadCell = [[AwfulThreadCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    self.threadCell.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.threadCell.pageIconHidden = YES;
    [self.webView.scrollView addSubview:self.threadCell];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.threadCell.frame = CGRectMake(0, -75, CGRectGetWidth(self.view.bounds), 75);
    UIEdgeInsets insets = self.webView.scrollView.contentInset;
    insets.top += CGRectGetHeight(self.threadCell.bounds);
    self.webView.scrollView.contentInset = insets;
}

- (AwfulTheme *)theme
{
    return [AwfulTheme currentThemeForForum:self.forum];
}

- (void)fetchPreviewIfNecessary
{
    if (self.fakePost || self.networkOperation) return;
    
    self.imageInterpolator = [AwfulSelfHostingAttachmentInterpolator new];
    NSString *interpolatedBBcode = [self.imageInterpolator interpolateImagesInString:self.BBcode];
    __weak __typeof__(self) weakSelf = self;
    self.networkOperation = [[AwfulForumsClient client] previewOriginalPostForThreadInForum:self.forum withBBcode:interpolatedBBcode andThen:^(NSError *error, NSString *postHTML) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            self.networkOperation = nil;
            AwfulThread *fakeThread = [AwfulThread insertInManagedObjectContext:self.managedObjectContext];
            fakeThread.author = [AwfulUser firstOrNewUserWithUserID:[AwfulSettings settings].userID
                                                           username:[AwfulSettings settings].username
                                             inManagedObjectContext:self.managedObjectContext];
            self.fakePost = [AwfulPost insertInManagedObjectContext:self.managedObjectContext];
            self.fakePost.thread = fakeThread;
            self.fakePost.author = fakeThread.author;
            self.fakePost.innerHTML = postHTML;
            self.fakePost.postDate = [NSDate date];
            [self renderPreview];
        }
    }];
}

- (void)renderPreview
{
    [super renderPreview];
    [self configureCell];
}

- (void)configureCell
{
    AwfulThreadCell *cell = self.threadCell;
    if ([AwfulSettings settings].showThreadTags) {
		cell.threadTagHidden = NO;
        AwfulThreadTagAndRatingView *tagAndRatingView = cell.tagAndRatingView;
        
		// It's possible to pick the same tag for the first and second icons in e.g. SA Mart.
		// Since it'd look ugly to show the e.g. "Selling" banner for each tag image, we just use
		// the empty thread tag for anyone lame enough to pick the same tag twice.
		if (self.threadTag.imageName.length > 0 && ![self.threadTag isEqual:self.secondaryThreadTag]) {
			UIImage *threadTag = [[AwfulThreadTagLoader loader] imageNamed:self.threadTag.imageName];
			tagAndRatingView.threadTagImage = threadTag;
		} else {
            tagAndRatingView.threadTagImage = [[AwfulThreadTagLoader loader] emptyThreadTagImage];
		}
		if (self.secondaryThreadTag) {
			UIImage *secondaryThreadTag = [[AwfulThreadTagLoader loader] imageNamed:self.secondaryThreadTag.imageName];
			tagAndRatingView.secondaryThreadTagImage = secondaryThreadTag;
		} else {
			tagAndRatingView.secondaryThreadTagImage = nil;
		}
	} else {
		cell.threadTagHidden = YES;
	}
	
    cell.textLabel.text = [self.subject stringByCollapsingWhitespace];
    cell.tagAndRatingView.alpha = 1;
    cell.textLabel.enabled = YES;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Posting in %@", self.forum.name];
    
    AwfulTheme *theme = self.theme;
    cell.backgroundColor = theme[@"listBackgroundColor"];
    cell.textLabel.textColor = theme[@"listTextColor"];
    cell.tintColor = theme[@"listDetailColor"];
    cell.fontName = theme[@"listFontName"];
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) return _managedObjectContext;
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    _managedObjectContext.parentContext = self.forum.managedObjectContext;
    return _managedObjectContext;
}

@end
