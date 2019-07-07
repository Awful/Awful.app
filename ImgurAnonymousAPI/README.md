# ImgurAnonymousAPI

Uploads images "anonymously" (i.e. unassociated with an account) using version 3 of the Imgur API.

This project is focused on taking an image in an app and uploading it to Imgur. It has no interest in providing a full-featured Imgur API client. Because the scope is so narrow, we can make the functionality we do offer as comfortable as possible:

* We accept the image types you're probably already using.
* We make it easy to upload images directly from an image picker.
* We cheerfully resize that gigantic image until it ducks below the Imgur file size limit.
* We resize that gigantic image without getting you terminated for eating all the device's memory.
* We depend only on Foundation and ImageIO (and optionally Photos and/or UIKit, as available).

## Getting started

You need to register your application with Imgur and otherwise comply with their terms. [Please read the Introduction section of the Imgur API documentation.](https://apidocs.imgur.com) At the time of writing, the Imgur API can be used for free for *non-commercial usage*. This project does not support commercial usage (though pull requests are welcome!). Once you've registered your application, record the Client ID that Imgur gives you. You'll need it to use this library!

Next step is to get a copy of this library. We support Carthage, CocoaPods, and Swift Package Manager, as well as just plopping a copy directly into your project.

Check out the included test application to see if this library will work with your images. To run that, open `ImgurAnonymousAPI.xcodeproj` and run the "iOSTestApp" scheme. (If you run into code signing issues, be sure to set your development team in the "iOSTestApp" target settings under the General tab in the Signing section.)

Here's an image picker-based example, assuming you've already got your image picker showing up:

```swift
import ImgurAnonymousAPI

class ViewController: UIImagePickerControllerDelegate {

    private let imgur = ImgurUploader(clientID: "my-client-id")
    
    // Somehow an image picker appears…

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
                               
        dismiss(animated: true)

        imgur.upload(info, completion: { result in
            switch result {
            case .success(let response):
                print("Image can be seen at \(response.link)")

            case .failure(let error):
                print("Upload failed: \(error)")
            }
        })
    }
}
```

## Notes and caveats

* The Imgur API has various rate limits in place. This library lets you keep track of that rate limiting, and you should probably pay attention at least to the "client" limits, as exeeceding them too often can get your API key banned for the rest of the month.
* Animated images are not fully supported. We will attempt to upload them, but they are not resized to fit under the maximum file size limit.
* To upload an animated image from an image picker, be sure to request photo library authorization from your user before showing the image picker. (This library won't prompt the user for you.)
* This library will never attempt to use the photo library unless the user has already authorized its use. This library will never trigger a photo library authorization prompt. And this library will never trigger a crash due to a missing `Info.plist` value for the key `NSPhotoLibraryUsageDescription` (remember that, as of iOS 11, you can have the user pick a photo without requiring authorization).
* Continuing the theme of anonymous image uploads, we use our own URL session with an ephemeral configuration.

## Development

Open the Xcode project and dig in!

There's some possibly interesting `DispatchIO` code in `WriteMultipartFormData` for writing out the `multipart/form-data` request using a combination of in-memory and on-disk data without loading everything at once. (Writing out the whole request to a file seemed preferable to using streams, as restarting streams can be finicky unless you write your own, and writing our own `InputStream` implementation seemed like a worse idea somehow.)
