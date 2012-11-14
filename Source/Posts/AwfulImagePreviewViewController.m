//
//  AwfulImagePreviewViewController.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-14.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulImagePreviewViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulThreadTitleLabel.h"
#import "SVProgressHUD.h"
#import "UIImageView+AFNetworking.h"

@interface AwfulImagePreviewViewController () <UIScrollViewDelegate, UIActionSheetDelegate,
                                               UIAlertViewDelegate>

@property (weak, nonatomic) UIScrollView *scrollView;

@property (weak, nonatomic) UIImageView *imageView;

@property (nonatomic) UIStatusBarStyle statusBarStyle;

@property (nonatomic) NSTimer *automaticallyHideBarsTimer;

@property (nonatomic) UIBarButtonItem *doneButton;

@property (nonatomic) UIBarButtonItem *actionButton;

@property (readonly, nonatomic) UILabel *titleLabel;

@end


@implementation AwfulImagePreviewViewController

- (id)initWithURL:(NSURL *)imageURL
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _imageURL = imageURL;
        self.wantsFullScreenLayout = YES;
        self.navigationItem.leftBarButtonItem = self.doneButton;
        self.navigationItem.rightBarButtonItem = self.actionButton;
        self.navigationItem.titleView = NewAwfulThreadTitleLabel();
    }
    return self;
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

- (UILabel *)titleLabel
{
    return (UILabel *)self.navigationItem.titleView;
}

- (void)updateImageView
{
    if (!self.imageURL) return;
    // Manually construct the request so cookies get sent. This is needed for images attached to
    // posts.
    NSURLRequest *request = [NSURLRequest requestWithURL:self.imageURL];
    [self.imageView setImageWithURLRequest:request
                          placeholderImage:nil
                                   success:^(NSURLRequest *request, NSHTTPURLResponse *response,
                                             UIImage *image)
     {
         // AFNetworking helpfully sets the image scale to the main screen's scale.
         image = [UIImage imageWithCGImage:image.CGImage
                                     scale:1
                               orientation:image.imageOrientation];
         self.imageView.image = image;
         self.imageView.backgroundColor = [UIColor whiteColor];
         [self.imageView sizeToFit];
         self.scrollView.contentSize = self.imageView.bounds.size;
         self.scrollView.minimumZoomScale = [self minimumZoomScale];
         self.scrollView.zoomScale = [self minimumZoomScale];
         self.scrollView.maximumZoomScale = 40;
         [self centerImageInScrollView];
     } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error)
     {
         UIAlertView *alert = [UIAlertView new];
         alert.title = @"Could Not Load Image";
         alert.message = [NSString stringWithFormat:@"%@ (error code %@)",
                          [error localizedDescription], @([error code])];
         [alert addButtonWithTitle:@"OK"];
         [alert show];
    }];
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
        self.scrollView.contentInset = UIEdgeInsetsZero;
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                withAnimation:UIStatusBarAnimationNone];
        [self.navigationController setNavigationBarHidden:NO animated:NO];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:YES
                                                withAnimation:UIStatusBarAnimationFade];
        CGFloat oldAlpha = self.navigationController.navigationBar.alpha;
        [UIView animateWithDuration:UINavigationControllerHideShowBarDuration animations:^{
            self.navigationController.navigationBar.alpha = 0;
        } completion:^(BOOL finished) {
            [self.navigationController setNavigationBarHidden:YES animated:NO];
            self.navigationController.navigationBar.alpha = oldAlpha;
        }];
    }
}

- (void)done
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showActions
{
    [self.automaticallyHideBarsTimer invalidate];
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    [sheet addButtonWithTitle:@"Save to Photos" block:^{
        [SVProgressHUD showWithStatus:@"Saving…" maskType:SVProgressHUDMaskTypeGradient];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *image = self.imageView.image;
            UIImageWriteToSavedPhotosAlbum(image, self, @selector(didSaveImage:error:contextInfo:),
                                           NULL);
        });
    }];
    [sheet addButtonWithTitle:@"Copy Image URL" block:^{
        [UIPasteboard generalPasteboard].URL = self.imageURL;
        [self hideBarsAfterShortDuration];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    sheet.delegate = self;
    [sheet showFromBarButtonItem:self.actionButton animated:YES];
}

- (void)didSaveImage:(UIImage *)image error:(NSError *)error contextInfo:(void *)contextInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            [SVProgressHUD dismiss];
            UIAlertView *alert = [UIAlertView new];
            alert.title = @"Could Not Save Image";
            alert.message = [NSString stringWithFormat:@"%@ (error code %@)",
                             [error localizedDescription], @([error code])];
            alert.delegate = self;
            [alert show];
        } else {
            [SVProgressHUD showSuccessWithStatus:@"Saved"];
            [self hideBarsAfterShortDuration];
        }
    });
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
    self.titleLabel.text = title;
}

- (void)loadView
{
    UIScrollView *scrollView = [UIScrollView new];
    self.scrollView = scrollView;
    scrollView.frame = [UIScreen mainScreen].bounds;
    scrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight);
    scrollView.delegate = self;
    scrollView.backgroundColor = [UIColor blackColor];
    UIImageView *imageView = [UIImageView new];
    imageView.frame = (CGRect){ .size = scrollView.frame.size };
    [scrollView addSubview:imageView];
    self.imageView = imageView;
    
    UIView *parent = [UIView new];
    parent.frame = scrollView.frame;
    parent.autoresizingMask = scrollView.autoresizingMask;
    [parent addSubview:scrollView];
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.statusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent
                                                animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self hideBarsAfterShortDuration];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.automaticallyHideBarsTimer invalidate];
    [[UIApplication sharedApplication] setStatusBarStyle:self.statusBarStyle animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:NO
                                            withAnimation:UIStatusBarAnimationNone];
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) return YES;
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
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
                        atScale:(float)scale
{
    // Implemented so zooming works.
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self hideBarsAfterShortDuration];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self hideBarsAfterShortDuration];
}

@end
