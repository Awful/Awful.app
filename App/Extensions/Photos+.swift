//  Photos+.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Photos

extension PHAsset {
    class func firstAsset(identifiedBy identifier: String) -> PHAsset? {
        return fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }
    
    #if !targetEnvironment(macCatalyst)
    class func firstAsset(withALAssetURL assetURL: URL) -> PHAsset? {
        return fetchAssets(withALAssetURLs: [assetURL], options: nil).firstObject
    }
    #endif
}

extension PHPhotoLibrary {

    enum AccessLevel {
        case addOnly, readWrite

        @available(iOS 14, *)
        fileprivate var phAccessLevel: PHAccessLevel {
            switch self {
            case .addOnly: return .addOnly
            case .readWrite: return .readWrite
            }
        }
    }

    class func authorizationStatus(for accessLevel: AccessLevel) -> PHAuthorizationStatus {
        if #available(iOS 14, *) {
            return authorizationStatus(for: accessLevel.phAccessLevel)
        } else {
            return authorizationStatus()
        }
    }

    class func requestAuthorization(
        for accessLevel: AccessLevel,
        handler: @escaping (PHAuthorizationStatus) -> Void
    ) {
        if #available(iOS 14, *) {
            requestAuthorization(for: accessLevel.phAccessLevel, handler: handler)
        } else {
            requestAuthorization(handler)
        }
    }
}
