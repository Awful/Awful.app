# PostImagesAPI

A Swift client for uploading images to PostImages.org.

This package provides a simple interface for uploading images to PostImages.org without requiring authentication. It supports uploading UIImages, PHAssets, and images from UIImagePickerController.

## Features

- Anonymous image uploads (no authentication required)
- Full-size image uploads (no automatic thumbnailing)
- Support for UIImage, PHAsset, and UIImagePickerController
- Progress tracking and cancellation

## Usage

```swift
import PostImagesAPI

let uploader = PostImagesUploader()

// Upload a UIImage
uploader.upload(image) { result in
    switch result {
    case .success(let response):
        print("Image uploaded to: \(response.imageURL)")
    case .failure(let error):
        print("Upload failed: \(error)")
    }
}
```