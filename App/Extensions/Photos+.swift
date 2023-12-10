//  Photos+.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Photos

extension PHAsset {
    class func firstAsset(identifiedBy identifier: String) -> PHAsset? {
        return fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }
}
