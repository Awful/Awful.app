// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import Foundation
import ImageIO

#if canImport(CoreServices)
    import CoreServices
#else
    import MobileCoreServices
#endif

/**
 Re-encodes an image into a format that Imgur accepts, if it isn't already in one.

 Imgur rejects HEIC uploads, and HEIC is what an iPhone camera produces by default. Photo library assets arrive here as their original, untouched camera files, so without this step those uploads fail.

 Anything that isn't JPEG, PNG, or GIF gets re-encoded as JPEG, or as PNG if the original has an alpha channel.

 The image is re-encoded without being fully dragged into memory.
 */
internal final class TranscodeImage: AsynchronousOperation<ImageFile>, @unchecked Sendable {

    /// The image formats we're confident Imgur accepts. Everything else gets re-encoded.
    private static let acceptableTypes = [kUTTypeJPEG, kUTTypePNG, kUTTypeGIF]

    /// High enough that the recompression isn't noticeable.
    private static let compressionQuality = 0.9

    /**
     Transcoding decodes the whole image into a bitmap, so cap how big that bitmap gets.

     A 48 megapixel photo is 8064x6048, which is about 195 MB of bitmap, and we're competing for memory with whatever the user is composing a post in. 4096 leaves a run-of-the-mill 12 megapixel photo (4032x3024) untouched, and keeps the peak around 50 MB for anything bigger. `kCGImageSourceThumbnailMaxPixelSize` is a maximum, so smaller images are never scaled up.
     */
    private static let maximumPixelSize = 4096

    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let originalImage = try firstDependencyValue(ofType: ImageFile.self)

        guard
            let imageSource = CGImageSourceCreateWithURL(originalImage.url as CFURL, nil),
            let uti = CGImageSourceGetType(imageSource) else
        {
            // Failing here isn't our job: ResizeImage or the upload itself will come up with a more useful error.
            log(.info, "could not identify the format of a .\(originalImage.url.pathExtension) image, so we'll just try the original")
            return finish(.success(originalImage))
        }

        if TranscodeImage.acceptableTypes.contains(where: { UTTypeConformsTo(uti, $0) }) {
            log(.debug, "original image is a \(uti) which Imgur accepts, so there's nothing to transcode")
            return finish(.success(originalImage))
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as NSDictionary?
        let hasAlpha = properties?[kCGImagePropertyHasAlpha] as? Bool ?? false
        let destinationType = hasAlpha ? kUTTypePNG : kUTTypeJPEG

        if CGImageSourceGetCount(imageSource) > 1 {
            log(.info, "original image has multiple frames, only the first of which survives transcoding")
        }

        let thumbnailOptions: NSDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Imgur doesn't reliably honour orientation metadata, so bake the transform into the pixels.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: TranscodeImage.maximumPixelSize,
            kCGImageSourceShouldCache: false]

        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions) else {
            log(.error, "could not decode \(uti) image for transcoding")
            throw ImageError.transcodingFailed
        }

        let pathExtension = UTTypeCopyPreferredTagWithClass(destinationType, kUTTagClassFilenameExtension)?.takeRetainedValue() as String? ?? "jpeg"
        let transcodedImageURL = tempFolder.url
            .appendingPathComponent("transcoded", isDirectory: false)
            .appendingPathExtension(pathExtension)

        guard let destination = CGImageDestinationCreateWithURL(transcodedImageURL as CFURL, destinationType, 1, nil) else {
            log(.error, "could not make a \(destinationType) destination at \(transcodedImageURL)")
            throw ImageError.destinationCreationFailed
        }

        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: TranscodeImage.compressionQuality,
            // The orientation transform is already baked in above.
            kCGImagePropertyOrientation: CGImagePropertyOrientation.up.rawValue,
            // Brings the wide gamut that HEIC captures typically use back down to sRGB.
            kCGImageDestinationOptimizeColorForSharing: true
        ] as NSDictionary)

        guard CGImageDestinationFinalize(destination) else {
            log(.error, "could not save transcoded image to \(transcodedImageURL)")
            throw ImageError.destinationFinalizationFailed
        }

        let originalByteSize = (try? originalImage.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        let transcodedByteSize = (try? transcodedImageURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        log(.info, "transcoded \(uti) image of \(originalByteSize as Any) bytes into a \(destinationType) of \(transcodedByteSize as Any) bytes, as Imgur may not accept the original format")

        finish(.success(ImageFile(url: transcodedImageURL)))
    }
}
