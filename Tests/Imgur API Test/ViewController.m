//
//  ViewController.m
//  Imgur API Test
//
//  Created by Nolan Waite on 2012-12-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ViewController.h"
#import "ImgurHTTPClient.h"
#import "SVProgressHUD.h"

@interface ViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic) IBOutlet UILabel *urlLabel;

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
    [self dismissViewControllerAnimated:YES completion:^{
        [SVProgressHUD showWithStatus:@"Uploading image…" maskType:SVProgressHUDMaskTypeBlack];
    }];
    [[ImgurHTTPClient client] uploadImages:@[ info[UIImagePickerControllerOriginalImage] ]
                                         andThen:^(NSError *error, NSArray *urls)
    {
        if (error) {
            [SVProgressHUD showErrorWithStatus:@"Upload failed"];
            NSLog(@"upload error: %@ (inner: %@)", error, [error userInfo][NSUnderlyingErrorKey]);
            return;
        }
        self.urlLabel.text = [urls[0] absoluteString];
        [SVProgressHUD showSuccessWithStatus:@"Uploaded image"];
    }];
}

@end
