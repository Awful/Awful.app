//  ImageUploadManager.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import AwfulSettings
import ImgurAnonymousAPI
@_exported import PostImagesAPI
import Photos
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImageUploadManager")

/// Manages image uploads using the configured provider (Imgur or PostImages)
public final class ImageUploadManager {
    
    public static let shared = ImageUploadManager()
    
    @FoilDefaultStorage(Settings.imageHostingProvider) private var imageHostingProvider
    @FoilDefaultStorage(Settings.imgurUploadMode) private var imgurUploadMode
    
    private init() {}
    
    /// Get the current upload provider based on settings
    private var currentProvider: ImageUploadProvider {
        switch imageHostingProvider {
        case .postImages:
            logger.debug("Using PostImages provider")
            return PostImagesUploadProviderAdapter()
            
        case .imgur:
            logger.debug("Using Imgur provider (mode: \(self.imgurUploadMode.rawValue))")
            return ImgurUploadProviderAdapter()
        }
    }
    
    /// Check if authentication is needed before uploading
    public var needsAuthentication: Bool {
        switch imageHostingProvider {
        case .postImages:
            return false
        case .imgur:
            return imgurUploadMode == .account && !ImgurAuthManager.shared.isAuthenticated
        }
    }
    
    /// Upload a UIImage
    @discardableResult
    public func upload(_ image: UIImage, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        if needsAuthentication {
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            DispatchQueue.main.async {
                completion(.failure(ImageUploadProviderError.providerUnavailable))
            }
            return progress
        }
        
        return currentProvider.upload(image, completion: completion)
    }
    
    /// Upload a Photos asset
    @discardableResult
    public func upload(_ asset: PHAsset, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        if needsAuthentication {
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            DispatchQueue.main.async {
                completion(.failure(ImageUploadProviderError.providerUnavailable))
            }
            return progress
        }
        
        return currentProvider.upload(asset, completion: completion)
    }
    
    /// Upload from image picker info dictionary
    @discardableResult
    public func upload(_ info: [UIImagePickerController.InfoKey: Any], completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        if needsAuthentication {
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            DispatchQueue.main.async {
                completion(.failure(ImageUploadProviderError.providerUnavailable))
            }
            return progress
        }
        
        return currentProvider.upload(info, completion: completion)
    }
}

// MARK: - Provider Adapters

/// Adapter to make ImgurUploader conform to ImageUploadProvider
private class ImgurUploadProviderAdapter: ImageUploadProvider {
    
    func upload(_ image: UIImage, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        return ImgurUploader.shared.upload(image) { result in
            switch result {
            case .success(let response):
                let uploadResponse = ImageUploadResponse(
                    imageURL: response.link,
                    deleteURL: nil, // Could be constructed from delete hash if needed
                    metadata: [
                        "id": response.id,
                        "postLimit": response.postLimit as Any,
                        "rateLimit": response.rateLimit as Any
                    ]
                )
                completion(.success(uploadResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func upload(_ asset: PHAsset, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        return ImgurUploader.shared.upload(asset) { result in
            switch result {
            case .success(let response):
                let uploadResponse = ImageUploadResponse(
                    imageURL: response.link,
                    deleteURL: nil,
                    metadata: [
                        "id": response.id,
                        "postLimit": response.postLimit as Any,
                        "rateLimit": response.rateLimit as Any
                    ]
                )
                completion(.success(uploadResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func upload(_ info: [UIImagePickerController.InfoKey : Any], completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        return ImgurUploader.shared.upload(info) { result in
            switch result {
            case .success(let response):
                let uploadResponse = ImageUploadResponse(
                    imageURL: response.link,
                    deleteURL: nil,
                    metadata: [
                        "id": response.id,
                        "postLimit": response.postLimit as Any,
                        "rateLimit": response.rateLimit as Any
                    ]
                )
                completion(.success(uploadResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

/// Adapter to make PostImagesUploader conform to ImageUploadProvider
private class PostImagesUploadProviderAdapter: ImageUploadProvider {
    
    private let uploader = PostImagesUploader()
    
    func upload(_ image: UIImage, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        return uploader.upload(image) { result in
            switch result {
            case .success(let response):
                let uploadResponse = ImageUploadResponse(
                    imageURL: response.imageURL,
                    deleteURL: nil, // PostImages doesn't provide deletion URLs
                    metadata: [
                        "directLink": response.directLink as Any,
                        "viewerLink": response.viewerLink as Any,
                        "thumbnailLink": response.thumbnailLink as Any
                    ]
                )
                completion(.success(uploadResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func upload(_ asset: PHAsset, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        return uploader.upload(asset) { result in
            switch result {
            case .success(let response):
                let uploadResponse = ImageUploadResponse(
                    imageURL: response.imageURL,
                    deleteURL: nil,
                    metadata: [
                        "directLink": response.directLink as Any,
                        "viewerLink": response.viewerLink as Any,
                        "thumbnailLink": response.thumbnailLink as Any
                    ]
                )
                completion(.success(uploadResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func upload(_ info: [UIImagePickerController.InfoKey : Any], completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress {
        return uploader.upload(info) { result in
            switch result {
            case .success(let response):
                let uploadResponse = ImageUploadResponse(
                    imageURL: response.imageURL,
                    deleteURL: nil,
                    metadata: [
                        "directLink": response.directLink as Any,
                        "viewerLink": response.viewerLink as Any,
                        "thumbnailLink": response.thumbnailLink as Any
                    ]
                )
                completion(.success(uploadResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
