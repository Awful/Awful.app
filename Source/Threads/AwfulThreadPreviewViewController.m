//  AwfulThreadPreviewViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadPreviewViewController.h"
#import "AwfulForumsClient.h"
#import "AwfulForumTweaks.h"
#import "AwfulSelfHostingAttachmentInterpolator.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThreadTagLoader.h"
#import "Awful-Swift.h"

@interface AwfulThreadPreviewViewController ()

@property (strong, nonatomic) ThreadCell *threadCell;

@property (strong, nonatomic) NSOperation *networkOperation;
@property (strong, nonatomic) AwfulSelfHostingAttachmentInterpolator *imageInterpolator;

@property (strong, nonatomic) Post *fakePost;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation AwfulThreadPreviewViewController

- (instancetype)initWithForum:(AwfulForum *)forum
                      subject:(NSString *)subject
                    threadTag:(ThreadTag *)threadTag
           secondaryThreadTag:(ThreadTag *)secondaryThreadTag
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
    self.threadCell = [[NSBundle mainBundle] loadNibNamed:@"ThreadCell" owner:nil options:nil][0];
    self.threadCell.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.webView.scrollView addSubview:self.threadCell];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self repositionCell];
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
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
        } else if (self) {
            self.networkOperation = nil;
            AwfulThread *fakeThread = [AwfulThread insertInManagedObjectContext:self.managedObjectContext];
            fakeThread.author = [AwfulUser firstOrNewUserWithUserID:[AwfulSettings sharedSettings].userID
                                                           username:[AwfulSettings sharedSettings].username
                                             inManagedObjectContext:self.managedObjectContext];
            self.fakePost = [Post insertInManagedObjectContext:self.managedObjectContext];
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
    if ([AwfulSettings sharedSettings].showThreadTags) {
		self.threadCell.showsTag = YES;
        
		// It's possible to pick the same tag for the first and second icons in e.g. SA Mart.
		// Since it'd look ugly to show the e.g. "Selling" banner for each tag image, we just use
		// the empty thread tag for anyone lame enough to pick the same tag twice.
		if (self.threadTag.imageName.length > 0 && ![self.threadTag isEqual:self.secondaryThreadTag]) {
			UIImage *threadTag = [AwfulThreadTagLoader imageNamed:self.threadTag.imageName];
            self.threadCell.tagImageView.image = threadTag;
		} else {
            self.threadCell.tagImageView.image = [AwfulThreadTagLoader emptyThreadTagImage];
		}
		if (self.secondaryThreadTag) {
			UIImage *secondaryThreadTag = [AwfulThreadTagLoader imageNamed:self.secondaryThreadTag.imageName];
            self.threadCell.secondaryTagImageView.image = secondaryThreadTag;
		} else {
            self.threadCell.secondaryTagImageView.image = nil;
		}
	} else {
		self.threadCell.showsTag = NO;
	}
	
    self.threadCell.titleLabel.text = [self.subject stringByCollapsingWhitespace];
    self.threadCell.tagAndRatingContainerView.alpha = 1;
    self.threadCell.titleLabel.enabled = YES;
    self.threadCell.numberOfPagesLabel.text = @"1";
    self.threadCell.killedByLabel.text = [NSString stringWithFormat:@"Posting in %@", self.forum.name];
    
    AwfulTheme *theme = self.theme;
    self.threadCell.backgroundColor = theme[@"listBackgroundColor"];
    self.threadCell.titleLabel.textColor = theme[@"listTextColor"];
    self.threadCell.numberOfPagesLabel.textColor = theme[@"listSecondaryTextColor"];
    self.threadCell.killedByLabel.textColor = theme[@"listSecondaryTextColor"];
    self.threadCell.tintColor = theme[@"listSecondaryTextColor"];
    [self.threadCell setFontNameForLabels:theme[@"listFontName"]];
    
    [self repositionCell];
}
                       
- (void)repositionCell
{
    CGSize cellSize = CGSizeMake(CGRectGetWidth(self.view.bounds), 10000);
    self.threadCell.frame = (CGRect){.size = cellSize};
    [self.threadCell setNeedsLayout];
    [self.threadCell layoutIfNeeded];
    
    // TODO Not sure how Interface Builder's "automatic" works programmatically, so fake it here.
    self.threadCell.titleLabel.preferredMaxLayoutWidth = CGRectGetWidth(self.threadCell.titleLabel.bounds);
    cellSize.height = [self.threadCell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    self.threadCell.frame = (CGRect){ .origin.y = -cellSize.height, .size = cellSize };
    UIEdgeInsets insets = self.webView.scrollView.contentInset;
    insets.top = self.topLayoutGuide.length + CGRectGetHeight(self.threadCell.bounds);
    self.webView.scrollView.contentInset = insets;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) return _managedObjectContext;
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    _managedObjectContext.parentContext = self.forum.managedObjectContext;
    return _managedObjectContext;
}

@end
