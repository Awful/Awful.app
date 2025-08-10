//  PostImagesUploader.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import Photos
import UIKit
import os

private let logger = Logger(subsystem: "com.awfulapp.Awful.PostImagesAPI", category: "PostImagesUploader")

/// A client for uploading images to PostImages.org
public final class PostImagesUploader {
    
    private let session: URLSession
    private let queue: OperationQueue
    
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = [
            "User-Agent": "Awful iOS App"
        ]
        self.session = URLSession(configuration: config)
        
        self.queue = OperationQueue()
        self.queue.name = "com.awfulapp.PostImagesAPI"
        self.queue.maxConcurrentOperationCount = 2
    }
    
    /// Upload a UIImage to PostImages
    public func upload(_ image: UIImage, completion: @escaping (Result<PostImagesResponse, Error>) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 100)
        
        // Try to preserve PNG format for images with transparency, otherwise use JPEG for better compression
        let (imageData, filename, mimeType): (Data?, String, String)
        if let pngData = image.pngData() {
            // Check if image has alpha channel (transparency)
            let hasAlpha = image.cgImage?.alphaInfo != .none && image.cgImage?.alphaInfo != .noneSkipLast && image.cgImage?.alphaInfo != .noneSkipFirst
            
            if hasAlpha {
                // Keep as PNG to preserve transparency
                imageData = pngData
                filename = "image.png"
                mimeType = "image/png"
            } else if let jpegData = image.jpegData(compressionQuality: 0.9) {
                // Convert to JPEG for better compression if no transparency
                imageData = jpegData
                filename = "image.jpg"
                mimeType = "image/jpeg"
            } else {
                // Fallback to PNG
                imageData = pngData
                filename = "image.png"
                mimeType = "image/png"
            }
        } else {
            imageData = nil
            filename = "image.jpg"
            mimeType = "image/jpeg"
        }
        
        guard let data = imageData else {
            DispatchQueue.main.async {
                completion(.failure(PostImagesError.invalidImageData))
            }
            progress.completedUnitCount = 100
            return progress
        }
        
        Task {
            do {
                progress.completedUnitCount = 10
                let response = try await uploadImageData(data, filename: filename, mimeType: mimeType, progress: progress)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            progress.completedUnitCount = 100
        }
        
        return progress
    }
    
    /// Upload a Photos asset to PostImages
    public func upload(_ asset: PHAsset, completion: @escaping (Result<PostImagesResponse, Error>) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 100)
        
        Task {
            do {
                progress.completedUnitCount = 5
                
                // Request image data from the asset
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                
                let (imageData, dataUTI) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, String?), Error>) in
                    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, orientation, info in
                        if let error = info?[PHImageErrorKey] as? Error {
                            continuation.resume(throwing: error)
                        } else if let data = data {
                            continuation.resume(returning: (data, dataUTI))
                        } else {
                            continuation.resume(throwing: PostImagesError.assetLoadFailed)
                        }
                    }
                }
                
                progress.completedUnitCount = 20
                
                // Determine filename and MIME type based on the UTI
                let (filename, mimeType): (String, String)
                if let uti = dataUTI {
                    if uti.contains("png") {
                        filename = "image.png"
                        mimeType = "image/png"
                    } else if uti.contains("gif") {
                        filename = "image.gif"
                        mimeType = "image/gif"
                    } else if uti.contains("heic") || uti.contains("heif") {
                        // Convert HEIC/HEIF to JPEG as PostImages might not support it
                        filename = "image.jpg"
                        mimeType = "image/jpeg"
                    } else {
                        // Default to JPEG
                        filename = "image.jpg"
                        mimeType = "image/jpeg"
                    }
                } else {
                    // Default to JPEG if no UTI available
                    filename = "image.jpg"
                    mimeType = "image/jpeg"
                }
                
                let response = try await uploadImageData(imageData, filename: filename, mimeType: mimeType, progress: progress)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            progress.completedUnitCount = 100
        }
        
        return progress
    }
    
    /// Upload from UIImagePickerController info dictionary
    public func upload(_ info: [UIImagePickerController.InfoKey: Any], completion: @escaping (Result<PostImagesResponse, Error>) -> Void) -> Progress {
        // Try to get a PHAsset first (for better quality)
        if let asset = info[.phAsset] as? PHAsset {
            return upload(asset, completion: completion)
        }
        
        // Fall back to UIImage
        if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
            return upload(image, completion: completion)
        }
        
        let progress = Progress(totalUnitCount: 1)
        progress.completedUnitCount = 1
        DispatchQueue.main.async {
            completion(.failure(PostImagesError.noImageInPickerInfo))
        }
        return progress
    }
    
    // MARK: - Private Methods
    
    // PostImages.org file size limit - 32MB as confirmed by testing
    private static let maxFileSize = 32 * 1024 * 1024 // 32MB
    
    private func uploadImageData(_ data: Data, filename: String, mimeType: String = "image/jpeg", progress: Progress) async throws -> PostImagesResponse {
        // Check file size limit
        if data.count > Self.maxFileSize {
            logger.warning("Image size \(data.count) bytes exceeds PostImages limit of \(Self.maxFileSize) bytes")
            throw PostImagesError.fileTooLarge(sizeInBytes: data.count, maxSizeInBytes: Self.maxFileSize)
        }
        
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: URL(string: "https://postimages.org/json")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart form data
        var body = Data()
        
        // Add parameters
        let parameters = [
            "mode": "punbb",
            "lang": "english",
            "code": "hotlink",
            "content": "",
            "adult": "",
            "optsize": "0", // No resizing, upload full image
            "upload_session": UUID().uuidString,
            "numfiles": "1",
            "gallery": "",
            "ui": generateUIString(),
            "upload_referer": "https://awfulapp.com",
            "forumurl": "https://forums.somethingawful.com"
        ]
        
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        progress.completedUnitCount = 30
        
        logger.debug("Uploading image to PostImages (\(data.count) bytes)")
        
        let (responseData, response) = try await session.data(for: request)
        
        progress.completedUnitCount = 90
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostImagesError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            logger.error("PostImages upload failed with status: \(httpResponse.statusCode)")
            throw PostImagesError.uploadFailed("HTTP \(httpResponse.statusCode)")
        }
        
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            logger.error("Failed to parse PostImages response")
            throw PostImagesError.invalidResponse
        }
        
        logger.debug("PostImages response: \(String(describing: json))")
        
        // Extract the viewer URL from the response
        guard let status = json["status"] as? String, status == "OK" else {
            let error = json["error"] as? String ?? "Unknown error"
            throw PostImagesError.uploadFailed(error)
        }
        
        guard let viewerUrlString = json["url"] as? String else {
            throw PostImagesError.invalidResponse
        }
        
        // Now we need to make a second request to /mod to get the BBCode with the direct image link
        // This mimics what postimages.js does on line 278-289
        let modParams = [
            "to": viewerUrlString,
            "mode": "punbb",
            "hash": "1",
            "lang": "english",
            "code": "hotlink", // We want hotlink code for direct image URL
            "content": "",
            "forumurl": "https://forums.somethingawful.com",
            "areaid": UUID().uuidString,
            "errors": "0",
            "dz": "1"
        ]
        
        var modUrlComponents = URLComponents(string: "https://postimages.org/mod")!
        modUrlComponents.queryItems = modParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let modUrl = modUrlComponents.url else {
            throw PostImagesError.invalidResponse
        }
        
        var modRequest = URLRequest(url: modUrl)
        modRequest.httpMethod = "GET"
        
        logger.debug("Getting BBCode from PostImages /mod endpoint")
        
        let (modData, modResponse) = try await session.data(for: modRequest)
        
        guard let modHttpResponse = modResponse as? HTTPURLResponse,
              modHttpResponse.statusCode == 200 else {
            logger.error("Failed to get BBCode from PostImages")
            throw PostImagesError.invalidResponse
        }
        
        // The response is BBCode text, not JSON
        guard let bbcode = String(data: modData, encoding: .utf8) else {
            throw PostImagesError.invalidResponse
        }
        
        logger.debug("BBCode response: \(bbcode)")
        
        // Extract the direct image URL from the BBCode
        // BBCode format is typically [img]https://i.postimg.cc/xxxxx/image.jpg[/img]
        let imgPattern = #"\[img\](.*?)\[/img\]"#
        guard let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: bbcode, range: NSRange(bbcode.startIndex..., in: bbcode)),
              let urlRange = Range(match.range(at: 1), in: bbcode) else {
            // If we can't parse BBCode, fall back to the viewer URL
            logger.warning("Could not extract image URL from BBCode, using viewer URL")
            return PostImagesResponse(
                imageURL: URL(string: viewerUrlString)!,
                directLink: nil,
                viewerLink: viewerUrlString,
                thumbnailLink: nil
            )
        }
        
        let directImageUrl = String(bbcode[urlRange])
        
        guard let imageUrl = URL(string: directImageUrl) else {
            throw PostImagesError.invalidResponse
        }
        
        logger.info("Successfully uploaded image to PostImages: \(imageUrl.absoluteString)")
        
        return PostImagesResponse(
            imageURL: imageUrl,
            directLink: directImageUrl,
            viewerLink: viewerUrlString,
            thumbnailLink: json["thumb_link"] as? String
        )
    }
    
    private func generateUIString() -> String {
        // Use constant values instead of real device info for privacy
        // These are generic iOS device values that won't identify users
        var ui = ""
        ui += "2"        // Retina display scale (most iOS devices)
        ui += "375"      // Generic iPhone width
        ui += "667"      // Generic iPhone height  
        ui += "true"     // cookies enabled
        ui += "en_US"    // Generic locale
        ui += "en_US"    // Generic locale
        ui += Date().description  // Current date is fine
        ui += "Awful iOS"
        return ui
    }
}

/// Response from PostImages upload
public struct PostImagesResponse {
    /// The main image URL (direct link to full image)
    public let imageURL: URL
    
    /// Direct link to the image file
    public let directLink: String?
    
    /// Link to the PostImages viewer page
    public let viewerLink: String?
    
    /// Link to thumbnail (if available)
    public let thumbnailLink: String?
}

/// Errors specific to PostImages uploads
public enum PostImagesError: LocalizedError {
    case invalidImageData
    case assetLoadFailed
    case noImageInPickerInfo
    case invalidResponse
    case uploadFailed(String)
    case fileTooLarge(sizeInBytes: Int, maxSizeInBytes: Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Could not convert image to data"
        case .assetLoadFailed:
            return "Failed to load image from photo library"
        case .noImageInPickerInfo:
            return "No image found in picker selection"
        case .invalidResponse:
            return "Invalid response from PostImages"
        case .uploadFailed(let message):
            return "PostImages upload failed: \(message)"
        case .fileTooLarge(let size, let maxSize):
            let sizeMB = Double(size) / (1024 * 1024)
            let maxSizeMB = Double(maxSize) / (1024 * 1024)
            return String(format: "Image is too large (%.1fMB). Maximum size is %.0fMB", sizeMB, maxSizeMB)
        }
    }
}