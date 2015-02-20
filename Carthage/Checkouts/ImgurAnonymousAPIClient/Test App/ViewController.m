//  ViewController.m
//
//  Public domain. https://github.com/nolanw/ImgurAnonymousAPIClient

#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "ImgurAnonymousAPIClient.h"

@interface ViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate, UIActionSheetDelegate>

@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) NSURL *assetURL;
@property (strong, nonatomic) NSURL *imgurURL;

@property (strong, nonatomic) NSProgress *uploadProgress;

@property (weak, nonatomic) IBOutlet UIButton *chooseImageButton;
@property (weak, nonatomic) IBOutlet UIButton *uploadButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *URLButton;
@property (weak, nonatomic) IBOutlet UIView *uploadingHUD;

@end

@implementation ViewController
{
    UIPopoverController *_popover;
}

- (void)updateUserInterface
{
    self.imageView.image = self.image;
    
    self.uploadButton.enabled = !!self.image;
    
    self.uploadingHUD.hidden = !self.uploadProgress;
    
    [self.URLButton setTitle:self.imgurURL.absoluteString forState:UIControlStateNormal];
    self.URLButton.enabled = !!self.imgurURL;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateUserInterface];
}

- (IBAction)chooseImage:(UIButton *)sender
{
    [self showImagePickerFromButton:sender animated:YES];
}

- (void)showImagePickerAnimated:(BOOL)animated
{
    [self showImagePickerFromButton:self.chooseImageButton animated:animated];
}

- (void)showImagePickerFromButton:(UIButton *)button animated:(BOOL)animated
{
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.delegate = self;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:picker];
        _popover.delegate = self;
        [_popover presentPopoverFromRect:button.bounds inView:button permittedArrowDirections:UIPopoverArrowDirectionAny animated:animated];
    } else {
        [self presentViewController:picker animated:animated completion:nil];
    }
}

- (IBAction)upload:(UIButton *)button
{
    UIActionSheet *actionSheet = [UIActionSheet new];
    actionSheet.delegate = self;
    [actionSheet addButtonWithTitle:@"As a UIImage"];
    [actionSheet addButtonWithTitle:@"As an ALAsset"];
    [actionSheet addButtonWithTitle:@"As an NSData"];
    [actionSheet addButtonWithTitle:@"As a file"];
    [actionSheet addButtonWithTitle:@"As a stream"];
    actionSheet.cancelButtonIndex = actionSheet.numberOfButtons;
    [actionSheet addButtonWithTitle:@"Cancel"];
    [actionSheet showFromRect:button.bounds inView:button animated:YES];
}

- (IBAction)cancelUpload:(id)sender
{
    [self.uploadProgress cancel];
}

- (IBAction)openURLInSafari:(id)sender
{
    NSURL *URL = [NSURL URLWithString:[sender titleForState:UIControlStateNormal]];
    [[UIApplication sharedApplication] openURL:URL];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    self.assetURL = info[UIImagePickerControllerReferenceURL];
    self.imgurURL = nil;
    [self updateUserInterface];
    
    if (_popover) {
        [_popover dismissPopoverAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == navigationController.viewControllers.firstObject) {
        viewController.title = @"Choose Image";
    }
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
    *rect = (*view).bounds;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    self.imgurURL = nil;
    
    __weak __typeof__(self) weakSelf = self;
    void (^completionHandler)() = ^(NSURL *imgurURL, NSError *error) {
        __typeof__(self) self = weakSelf;
        self.uploadProgress = nil;
        if (error) {
            UIAlertView *alert = [UIAlertView new];
            alert.title = @"Error Uploading Image";
            alert.message = error.localizedDescription;
            [alert addButtonWithTitle:@"OK"];
            [alert show];
            NSLog(@"error: %@", error);
        } else {
            self.imgurURL = imgurURL;
        }
        [self updateUserInterface];
    };
    
    // UIImage
    // ALAsset
    // NSData
    // file
    // stream
    if (buttonIndex == 0) {
        self.uploadProgress = [[ImgurAnonymousAPIClient sharedClient] uploadImage:self.image withFilename:@"image.png" completionHandler:completionHandler];
    } else if (buttonIndex == 1) {
        self.uploadProgress = [[ImgurAnonymousAPIClient sharedClient] uploadAssetWithURL:self.assetURL filename:nil completionHandler:completionHandler];
    } else {
        NSData *data = UIImagePNGRepresentation(self.image);
        if (buttonIndex == 2) {
            self.uploadProgress = [[ImgurAnonymousAPIClient sharedClient] uploadImageData:data withFilename:@"image.png" completionHandler:completionHandler];
        } else if (buttonIndex == 3) {
            NSURL *cachesFolder = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
            NSURL *fileURL = [cachesFolder URLByAppendingPathComponent:@"image.png"];
            [data writeToURL:fileURL atomically:NO];
            self.uploadProgress = [[ImgurAnonymousAPIClient sharedClient] uploadImageFile:fileURL withFilename:nil completionHandler:completionHandler];
        } else if (buttonIndex == 4) {
            NSInputStream *stream = [NSInputStream inputStreamWithData:data];
            self.uploadProgress = [[ImgurAnonymousAPIClient sharedClient] uploadStreamedImage:stream length:data.length withFilename:@"image.png" completionHandler:completionHandler];
        } else {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Too many buttons" userInfo:nil];
        }
    }
    
    [self updateUserInterface];
}

@end
