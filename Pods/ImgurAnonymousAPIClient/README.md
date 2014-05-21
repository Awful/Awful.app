# ImgurAnonymousAPIClient

An anonymous Imgur image uploader.

ImgurAnonymousAPIClient requires [AFNetworking 2.0 or higher][AFNetworking] and requires iOS 7.0 or OS X 10.9.

## Usage

ImgurAnonymousAPIClient is flexible:

```objc
// Put your client ID in Info.plist first! Then…

NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
[[ImgurAnonymousAPIClient client] uploadAssetWithURL:assetURL filename:nil completionHandler:^(NSURL *imgurURL, NSError *error) {
    // imgurURL is ready for you!
    // And the image was resized too, if needed.
    // Even the largest images work fine!
}];

// Or…

UIImage *image = info[UIImagePickerControllerEditedImage];
[[ImgurAnonymousAPIClient client] uploadImage:image withFilename:@"image.jpg" completionHandler:^(NSURL *imgurURL, NSError *error) {
    // imgurURL is ready for you!
    // And the image was resized too, if needed.
}];

// Or…

NSURL *fileURLForSomeImage = ...;
[[ImgurAnonymousAPIClient client] uploadImageFile:fileURLForSomeImage withFilename:nil completionHandler:^(NSURL *imgurURL, NSError *error) {
    // imgurURL is ready for you!
}];

// Or…

NSData *data = UIImageJPEGRepresentation(myImage, 0.9);
[[ImgurAnonymousAPIClient client] uploadImageData:data withFilename:@"image.jpg" completionHandler:^(NSURL *imgurURL, NSError *error) {
    // imgurURL is ready for you!
}];
```

## Installation

If you use CocoaPods, you can add to your `Podfile`:

```
pod 'ImgurAnonymousAPIClient', :git => 'https://github.com/nolanw/ImgurAnonymousAPIClient.git', :tag => 'v0.1'
```

Otherwise, the client is contained within the `ImgurAnonymousAPIClient.h` and `ImgurAnonymousAPIClient.m` files. Simply copy those two files into your project. You'll need to [install AFNetworking][AFNetworking] as well (version 2.2.2 or higher), if you aren't using it already. Finally, be sure to link against `ImageIO` and either `AssetsLibrary` and `MobileCoreServices` (on iOS) or `CoreServices` (on OS X).

Once you're all set, you need an Imgur API client ID. This is a requirement for using the Imgur API, which is what ImgurAnonymousAPIClient uses. Be sure to [register your application][register] and get the client ID.

You have three options for specifying your client ID. The most convenient is to put it in your `Info.plist` for the key `ImgurAnonymousAPIClientID`:

```objc
ImgurAnonymousAPIClient *client = [ImgurAnonymousAPIClient new]; // Uses client ID from Info.plist.
[ImgurAnonymousAPIClient client];                                // So does the convenient singleton.
```

Or create a client and give it the client ID:

```objc
ImgurAnonymousAPIClient *client = [[ImgurAnonymousAPIClient alloc] initWithClientID:@"YOURIDHERE"];
```

Or set the client ID after the client is created:

```objc
[ImgurAnonymousAPIClient client].clientID = @"YOURIDHERE";
```

[register]: https://api.imgur.com

## Alternatives

[ImgurSession][] is a full-featured Imgur API client. It supports the full API, including logging in via OAuth2. It should be your first stop if ImgurAnonymousAPIClient doesn't do what you need.

[ImgurSession]: https://github.com/geoffmacd/ImgurSession

## Example

There's a functional (i.e. aesthetically displeasing and not very usable) example app for iOS in the [Test App][] folder. It demonstrates several different ways to upload an image from the photo library, as well as how to cancel an upload in progress.

[Test App]: Test%20App

## Why

Uploading to Imgur is handy, but handling all the possible errors is a huge pain. Plus resizing images to fit the maximum file size can get hairy. ImgurAnonymousAPIClient wraps it all up.

[AFNetworking]: https://github.com/AFNetworking/AFNetworking#how-to-get-started
