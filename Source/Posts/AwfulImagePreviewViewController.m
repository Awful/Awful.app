//  AwfulImagePreviewViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulImagePreviewViewController.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulSettings.h"
@import AssetsLibrary;
@import SafariServices;
#import <AFNetworking/AFNetworking.h>
#import <FVGifAnimation.h>
#import <MRProgress/MRProgressOverlayView.h>
#import "Awful-Swift.h"

@interface AwfulImagePreviewViewController () <UIScrollViewDelegate>

@property (nonatomic) UIScrollView *scrollView;
@property (nonatomic) UIImageView *imageView;
@property (nonatomic) NSData *imageData;
@property (assign, nonatomic) BOOL imageIsGIF;

@property (nonatomic) NSOperationQueue *queue;

@property (nonatomic) NSTimer *automaticallyHideBarsTimer;

@property (nonatomic) UIBarButtonItem *doneButton;
@property (nonatomic) UIBarButtonItem *actionButton;

@end


@implementation AwfulImagePreviewViewController

- (id)initWithURL:(NSURL *)imageURL
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _imageURL = imageURL;
        self.navigationItem.leftBarButtonItem = self.doneButton;
        self.navigationItem.rightBarButtonItem = self.actionButton;
        _queue = [NSOperationQueue new];
        _queue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
    }
    return self;
}

- (void)dealloc
{
    _scrollView.delegate = nil;
}

- (void)setImageURL:(NSURL *)imageURL
{
    if ([_imageURL isEqual:imageURL]) return;
    _imageURL = imageURL;
    [self updateImageView];
}

- (UIBarButtonItem *)doneButton
{
    if (_doneButton) return _doneButton;
    _doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                target:self
                                                                action:@selector(done)];
    return _doneButton;
}

- (UIBarButtonItem *)actionButton
{
    if (_actionButton) return _actionButton;
    _actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                  target:self
                                                                  action:@selector(showActions)];
    return _actionButton;
}

- (void)updateImageView
{
    if (!self.imageURL) return;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.imageURL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseData) {
        self.imageData = responseData;
        FVGifAnimation *animation = [[FVGifAnimation alloc] initWithData:responseData];
        self.imageIsGIF = [animation canAnimate];
        if (self.imageIsGIF) {
            [animation setAnimationToImageView:self.imageView];
            [self.imageView startAnimating];
        } else {
            self.imageView.image = [UIImage imageWithData:responseData];
        }
        
        self.imageView.backgroundColor = [UIColor whiteColor];
        [self.imageView sizeToFit];
        self.scrollView.contentSize = self.imageView.bounds.size;
        self.scrollView.minimumZoomScale = [self minimumZoomScale];
        self.scrollView.zoomScale = [self minimumZoomScale];
        self.scrollView.maximumZoomScale = 40;
        [self centerImageInScrollView];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Load Image" error:error] animated:YES completion:nil];
    }];
    [self.queue addOperation:op];
}

- (CGFloat)minimumZoomScale
{
    CGFloat horizontal = self.scrollView.bounds.size.width / self.imageView.image.size.width;
    CGFloat vertical = self.scrollView.bounds.size.height / self.imageView.image.size.height;
    return MIN(MIN(horizontal, vertical), 1);
}

- (void)toggleVisibleBars
{
    [self.automaticallyHideBarsTimer invalidate];
    if (self.navigationController.navigationBarHidden) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    } else {
		[self.navigationController setNavigationBarHidden:YES animated:YES];

    }
}

- (void)done
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showActions
{
    if (self.presentedViewController) return;
    [self.automaticallyHideBarsTimer invalidate];
    UIAlertController *actionSheet = [UIAlertController actionSheet];
    
    [actionSheet addActionWithTitle:@"Save to Photos" handler:^{
        MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.view
                                                                             title:@"Saving"
                                                                              mode:MRProgressOverlayViewModeIndeterminate
                                                                          animated:YES];
        overlay.tintColor = self.theme[@"tintColor"];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[ALAssetsLibrary new] writeImageDataToSavedPhotosAlbum:self.imageData metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [overlay dismiss:YES completion:^{
                        if (error) {
                            UIAlertController *alert = [UIAlertController alertWithTitle:@"Could Not Save Image" error:error handler:^(UIAlertAction *alert) {
                                [self hideBarsAfterShortDuration];
                            }];
                            [self presentViewController:alert animated:YES completion:nil];
                        }
                    }];
                });
            }];
        });
    }];
    
    [actionSheet addActionWithTitle:@"Copy Image URL" handler:^{
        [AwfulSettings sharedSettings].lastOfferedPasteboardURL = self.imageURL.absoluteString;
        [UIPasteboard generalPasteboard].awful_URL = self.imageURL;
        [self hideBarsAfterShortDuration];
    }];
    
    if ([SSReadingList supportsURL:self.imageURL]) {
        [actionSheet addActionWithTitle:@"Send to Reading List" handler:^{
            NSError *error;
            if (![[SSReadingList defaultReadingList] addReadingListItemWithURL:self.imageURL title:self.title previewText:nil error:&error]) {
                [self presentViewController:[UIAlertController alertWithTitle:@"Error Adding Image" error:error] animated:YES completion:nil];
            }
        }];
    }
    
    [actionSheet addActionWithTitle:@"Copy Image" handler:^{
        if (self.imageIsGIF) {
            [[UIPasteboard generalPasteboard] setData:self.imageData forPasteboardType:(__bridge NSString *)kUTTypeGIF];
        } else {
            [UIPasteboard generalPasteboard].image = self.imageView.image;
        }
        [self hideBarsAfterShortDuration];
    }];
    
    [actionSheet addCancelActionWithHandler:^{
        [self hideBarsAfterShortDuration];
    }];
    
    [self presentViewController:actionSheet animated:YES completion:nil];
    actionSheet.popoverPresentationController.barButtonItem = self.actionButton;
}

- (void)hideBarsAfterShortDuration
{
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:6
                                                      target:self
                                                    selector:@selector(toggleVisibleBars)
                                                    userInfo:nil
                                                     repeats:NO];
    self.automaticallyHideBarsTimer = timer;
}

- (void)centerImageInScrollView
{
    CGPoint center = CGPointMake(self.scrollView.contentSize.width / 2,
                                 self.scrollView.contentSize.height / 2);
    if (self.scrollView.bounds.size.width > self.scrollView.contentSize.width) {
        center.x += (self.scrollView.bounds.size.width - self.scrollView.contentSize.width) / 2;
    }
    if (self.scrollView.bounds.size.height > self.scrollView.contentSize.height) {
        center.y += (self.scrollView.bounds.size.height - self.scrollView.contentSize.height) / 2;
    }
    self.imageView.center = center;
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithURL:nil];
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)loadView
{
    self.scrollView = [UIScrollView new];
    self.scrollView.frame = [UIScreen mainScreen].bounds;
    self.scrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                        UIViewAutoresizingFlexibleHeight);
    self.scrollView.delegate = self;
    self.scrollView.backgroundColor = [UIColor blackColor];
    self.imageView = [UIImageView new];
    self.imageView.frame = (CGRect){ .size = self.scrollView.frame.size };
    [self.scrollView addSubview:self.imageView];
    
    UIView *parent = [UIView new];
    parent.frame = self.scrollView.frame;
    parent.autoresizingMask = self.scrollView.autoresizingMask;
    [parent addSubview:self.scrollView];
    self.view = parent;
    
    UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
    [tap addTarget:self action:@selector(toggleVisibleBars)];
    [self.view addGestureRecognizer:tap];
    
    UISwipeGestureRecognizer *swipe = [UISwipeGestureRecognizer new];
    swipe.direction = UISwipeGestureRecognizerDirectionDown;
    [swipe addTarget:self action:@selector(done)];
    [self.view addGestureRecognizer:swipe];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateImageView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self hideBarsAfterShortDuration];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.automaticallyHideBarsTimer invalidate];
    [super viewWillDisappear:animated];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    self.scrollView.minimumZoomScale = [self minimumZoomScale];
    if (self.scrollView.zoomScale < self.scrollView.minimumZoomScale) {
        self.scrollView.zoomScale = self.scrollView.minimumZoomScale;
    }
    [self centerImageInScrollView];
}

-(BOOL)prefersStatusBarHidden
{
	return self.navigationController.navigationBarHidden;
}

-(UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
	return UIStatusBarAnimationSlide;
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    [self centerImageInScrollView];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView
                       withView:(UIView *)view
                        atScale:(CGFloat)scale
{
    // Implemented so zooming works.
}

@end
