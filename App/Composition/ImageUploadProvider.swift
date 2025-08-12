//  ImageUploadProvider.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import Photos
import UIKit

/// Common protocol for image upload providers (Imgur, PostImages, etc.)
public protocol ImageUploadProvider {
    /// Upload a UIImage
    @discardableResult
    func upload(_ image: UIImage, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress
    
    /// Upload a Photos asset
    @discardableResult
    func upload(_ asset: PHAsset, completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress
    
    /// Upload from image picker info dictionary
    @discardableResult
    func upload(_ info: [UIImagePickerController.InfoKey: Any], completion: @escaping (Result<ImageUploadResponse, Error>) -> Void) -> Progress
}

/// Standardized response from any image upload provider
public struct ImageUploadResponse {
    /// The URL of the uploaded image
    public let imageURL: URL
    
    /// Optional deletion URL/hash (not all providers support this)
    public let deleteURL: URL?
    
    /// Provider-specific metadata
    public let metadata: [String: Any]
    
    public init(imageURL: URL, deleteURL: URL? = nil, metadata: [String: Any] = [:]) {
        self.imageURL = imageURL
        self.deleteURL = deleteURL
        self.metadata = metadata
    }
}

/// Errors that can occur during image upload
public enum ImageUploadProviderError: LocalizedError {
    case unsupportedImageFormat
    case uploadFailed(String)
    case invalidResponse
    case providerUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedImageFormat:
            return "The image format is not supported"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .invalidResponse:
            return "Invalid response from image hosting service"
        case .providerUnavailable:
            return "Image hosting service is unavailable"
        }
    }
}