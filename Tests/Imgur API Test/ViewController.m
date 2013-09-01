//  ViewController.m
//  Imgur API Test
//
//

#import "ViewController.h"
#import "ImgurHTTPClient.h"
#import "SVProgressHUD.h"

@interface ViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic) IBOutlet UILabel *urlLabel;
@property (nonatomic) NSMutableArray *images;

@end

@implementation ViewController

- (IBAction)fromCamera
{
    [self showPickerForSourceType:UIImagePickerControllerSourceTypeCamera];
}

- (IBAction)fromLibrary
{
    [self showPickerForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (IBAction)upload
{
    self.urlLabel.text = @"Uploading images…";
    [[ImgurHTTPClient client] uploadImages:self.images
                                   andThen:^(NSError *error, NSArray *urls)
     {
         if (error) {
             self.urlLabel.text = [NSString stringWithFormat:@"upload error: %@ (inner: %@)\n"
                                   "tap Upload to retry",
                                   error, [error userInfo][NSUnderlyingErrorKey]];
         } else {
             self.urlLabel.text = [[urls valueForKey:@"absoluteString"] componentsJoinedByString:@"\n"];
             [self.images removeAllObjects];
         }
     }];
}

- (void)showPickerForSourceType:(UIImagePickerControllerSourceType)sourceType
{
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) {
        return;
    }
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = sourceType;
    picker.allowsEditing = NO;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    if (!self.images) self.images = [NSMutableArray new];
    [self.images addObject:info[UIImagePickerControllerOriginalImage]];
    self.urlLabel.text = [NSString stringWithFormat:@"Ready to upload %d image%@",
                          [self.images count], [self.images count] == 1 ? @"" : @"s"];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
